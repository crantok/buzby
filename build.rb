# The BSSB ("buzby") build script

# Maintenance notes:
#
#  - This code is littered with variables called 'metadata' or variations
#  thereof. Many LOC are spent on making sure metadata flows to where it is
#  intended. The metadata variables normally contain hashes and the hashes are
#  frequently merged to make new hashes. In order to read the hash merging
#  statements correctly, the reader needs to understand how duplicate keys are
#  handled in a hash merge. The hash to the right, i.e. the hash passed as an
#  argument, is the hash that dominates. Where duplicate keys exist, it is the
#  hash to the right whose values are preserved. It is the hash to the left,
#  i.e. the hash on which the merge method was called, whose values may be lost.
#
#    low_priority_metadata.merge other_metadata.merge high_priority_metadata


require 'fileutils'
require 'yaml'
require 'kramdown'
require 'nokogiri'
require 'pathname'
require_relative './view'


module Defaults

    # Put any default metadata here. This is different from putting the
    # same metadata in the root of the source directory in one way:
    # - Even if a directory or piece of content does not inherit its parent's
    # metadata (i.e. by using {'inherit_metadata'=>false} ), these defaults will
    # still apply when alternative values are not given for the same keys.
    #
    def self.metadata
        {
            'layout' => 'default_layout',
            'clean_urls' => true
            }
    end
end


module Filesystem

    # A bunch of constants that define the roots of source, destination and
    # other directory trees. Each directory string has an equivalent Pathname
    # object to make it easy to determine relative paths.
    #
    SCRIPT_DIR = File.dirname( __FILE__ )
    SRC_ROOT_DIR = "#{SCRIPT_DIR}/src"
    SRC_PATH = Pathname.new SRC_ROOT_DIR
    PUBLISHED_ROOT_DIR = "#{SCRIPT_DIR}/published"
    PUBLISHED_PATH = Pathname.new PUBLISHED_ROOT_DIR
    PREVIEW_ROOT_DIR = "#{SCRIPT_DIR}/preview"
    PREVIEW_PATH = Pathname.new PREVIEW_ROOT_DIR
    TMP_DIR = "#{SCRIPT_DIR}/tmp"
    TMP_PATH = Pathname.new TMP_DIR
    TEMPLATE_DIR = "#{SCRIPT_DIR}/templates"

    # Find the relative path from one directory to the given file, and then add
    # that relative path to a second directory to get a new location for the
    # file.
    #
    def self.new_path filename, old_dir_path, new_dir_path
        new_dir_path + (Pathname.new filename).relative_path_from(old_dir_path)
    end

    # Create required directories, then create a file with the given content.
    def self.write_file filename, file_content
        FileUtils.mkdir_p File.dirname( filename )
        File.open( filename, 'w' ) { |file| file.write file_content }
    end
end


module MetadataScraper

    ## TODO: Determine destination filenames here!
    ## We already have all the data we need
    ## Could supply a list of destination paths with procs to get dest filenames
    ## return nil if path inappropriate
    ## store dest filenames as an array to be iterated over - reduces logic required downstream

    private

    def self.conditionally_merge_inherited_metadata current_metadata, parent_metadata

        # From lowest to highest priority metadata:
        # Global defaults, parent metadata, {'inherit_metadata'=>true}, current metadata.
        # Obviously the current metadata can override {'inherit_metadata'=>true}
        # This means that the parent metadata is not always merged.
        # Global defaults are always merged, but may be overriden.

        # Use default metadata inheritance if user has not explicitly set it.
        metadata = { 'inherit_metadata' => true }.merge current_metadata

        # Merge in parent's metadata if metadata inheritance is being used.
        metadata = parent_metadata.merge metadata if metadata['inherit_metadata']

        # Merge values for any default settings the user has not explicitly set.
        Defaults.metadata.merge metadata
    end


    # For a given directory, get all the metadata defined in that directory and,
    # where applicable, combine it with any metadata from the directory's parent and
    # from Defaults.
    #
    def self.get_directory_metadata dir, parent_metadata

        # Set filesystem related metadata.
        metadata = { dir: dir, file_type: :directory }

        # Get directory-level metadata from any yaml files in this directory.
        metadata = Dir.glob( "#{dir}/*.yml" ).inject(metadata) do |hash,filename|
            YAML.load_file(filename).merge(hash)
        end

        conditionally_merge_inherited_metadata metadata, parent_metadata
    end


    # Get metadata relevant to a content file and, if applicable, combine with
    # directory metadata.
    #
    def self.get_content_metadata filename, directory_metadata

        # Set filesystem related metadata.
        metadata = { src_filename: filename, file_type: :content }

        # Get user-defined metadata from a frontmatter block.
        metadata = YAML.load_file(filename).merge metadata

        conditionally_merge_inherited_metadata metadata, directory_metadata
    end


    # Save the details of a view file, for processing when all metadata has been
    # assembled.
    #
    def self.get_view_metadata filename, directory_metadata
        conditionally_merge_inherited_metadata(
            { src_filename: filename, file_type: :view },
            directory_metadata )
    end

    # Save the details of an asset file, for copying later.
    #
    def self.get_asset_metadata filename, directory_metadata
        conditionally_merge_inherited_metadata(
            { src_filename: filename, file_type: :asset },
            directory_metadata )
    end

    public

    # A recursive function to process a directory and its files and subdirectories;
    # gathering metadata. Returns an array of metadata hashes, one per file.
    #
    def self.scrape dir, parent_metadata = {}, content = []

        directory_metadata = get_directory_metadata dir, parent_metadata
        content.push directory_metadata

        Dir.foreach dir do | filename |

            full_filename = "#{dir}/#{filename}"

            if File.directory? full_filename
                if ! ['.', '..'].include? filename
                    self.scrape full_filename, directory_metadata, content
                end

            else
                file_metadata = nil
                case filename
                when /\.yml/
                    # do nothing - we've already dealt with directory metadata
                when /\.md$/
                    file_metadata = get_content_metadata full_filename, directory_metadata
                when /\.mustache$/
                    file_metadata = get_view_metadata full_filename, directory_metadata
                else
                    file_metadata = get_asset_metadata full_filename, directory_metadata
                end
                content.push file_metadata if file_metadata
            end
        end
        content
    end
end


# Generate html fragments from markdown files and copy them to the tmp dir.
#
module MarkdownProcessor

    private

    def self.get_html_from_markdown_file filename
        all_text = File.open(filename) { |file| file.read }
        markdown = all_text[ (all_text.index(/^---/,3)+3)..-1 ]
        Kramdown::Document.new(
            markdown,
            { smart_quotes: ['apos','apos','quot','quot'] }
            ).to_html
    end


    def self.write_html_to_tmp_file html, src_filename
        tmp_filename = Filesystem.new_path(
            src_filename, Filesystem::SRC_PATH, Filesystem::TMP_PATH
            ).to_s.gsub( /md$/, 'content.html' )

        Filesystem.write_file tmp_filename, html

        tmp_filename
    end

    public

    # Select content files from metadata, convert them to html fragments and
    # save the results.
    #
    def self.process metadata
        metadata.select { |m| m[:file_type] == :content }.each do | properties |

            html = get_html_from_markdown_file properties[:src_filename]

            # provide a teaser if one has not been explicitly set in markdown
            properties['teaser'] ||= Nokogiri::HTML(html).at_css('p').to_html

            tmp_filename = write_html_to_tmp_file html, properties[:src_filename]
            properties[:tmp_filename] = tmp_filename
        end
    end
end


# Copy assets to destination directories and update metadata.
#
module AssetCopier

    private

    def self.copy_file src_filename, dst_path
        dst_filename =
            Filesystem.new_path( src_filename, Filesystem::SRC_PATH, dst_path )
        FileUtils.mkdir_p File.dirname(dst_filename)
        FileUtils.cp src_filename, dst_filename
        dst_filename
    end

    public

    # Copy asset files directly to the target directories and gather their metadata
    # in case it is required by any views.
    #
    def self.copy metadata

        metadata.select { |m| m[:file_type] == :asset }.each do | properties |

            pub_filename = copy_file properties[:src_filename], Filesystem::PUBLISHED_PATH
            properties[:pub_filename] = pub_filename

            pre_filename = copy_file properties[:src_filename], Filesystem::PREVIEW_PATH
            properties[:pre_filename] = pre_filename
        end
    end
end


# Inflate all content to full html files via mustache templates and layouts.
#
module ContentInflator

    private

    # Get the rendered content for an output file.
    #
    def self.get_output_file_content item, all_metadata

        context = item.merge( {
            all_metadata: all_metadata,
            content: File.open(item[:tmp_filename]) { |file| file.read }
            } )

        if item['content_type']
            inner = Mustache.render item['content_type'].to_sym, context
        else
            src_filename = item[:src_filename]
            abort "ERROR: Content file ( #{src_filename} ) does not specify 'content_type'."
        end

        layout = item.has_key?('layout') ? item['layout'] : Defaults.metadata['layout']

        output =
            if layout
                Mustache.render layout.to_sym, context.merge( { yield: inner } )
            else
                inner
            end
    end

    # Convert a path from x/y.html to x/y/index.html
    #
    def self.clean_content_path path
        path.gsub( %r{(/.*).html$}, '\1/index.html' )
    end

    # Get the url path as it will be used in links.
    #
    def self.url_path file_path, root_path
        '/' + Pathname.new( file_path ).relative_path_from( root_path ).to_s.gsub( %r{/index.html$}, '/' )
    end

    # For given tmp file and destination root, get the destination file's path
    #
    def self.content_path tmp_filename, target_root_path, clean_urls
        path = Filesystem.new_path(
            tmp_filename, Filesystem::TMP_PATH, target_root_path
            ).to_s.gsub( %r{content.html$}, 'html' )

        path =
        if clean_urls
            clean_content_path path
        else
            path
        end
    end

    # Write preview and (possibly) published files for the given content.
    #
    def self.write_output_files item, file_content

        preview_file_path = content_path(
            item[:tmp_filename], Filesystem::PREVIEW_PATH, item['clean_urls']
            )

        # Path relative to the site root, so should work for pre, pub, etc.
        item[:url_path] = url_path preview_file_path, Filesystem::PREVIEW_PATH

        Filesystem.write_file preview_file_path, file_content

        if item['published']
            Filesystem.write_file(
                content_path(
                    item[:tmp_filename],
                    Filesystem::PUBLISHED_PATH,
                    item['clean_urls']
                    ),
                file_content
                )
        end
    end

    public

    # Select all content files and inject their html fragment in to appropriate
    # templates to create pages. Write the pages to destination directories.
    #
    def self.inflate metadata

        # Config: could make this configurable.
        Mustache.template_path = Filesystem::TEMPLATE_DIR

        metadata.select { |m| m[:file_type] == :content }.each do | properties |
            content = get_output_file_content properties, metadata
            write_output_files properties, content
        end
    end

end

# Inflate all views. Note that the file produced might not be html,
# e.g. an RSS feed.
#
# TO DO: A lot of this module is a copy and paste of the content inflator. Rationalise this.
# TO DO: A lot of this module is a copy and paste of the content inflator. Rationalise this.
#
module ViewsInflator

    def self.render_view status, item, all_metadata

        context = item.merge( { status: status, all_metadata: all_metadata } )

        view = View.new
        view.template_file = item[:src_filename]
        inner = view.render context

        layout = item.has_key?('layout') ? item['layout'] : Defaults.metadata['layout']
        if layout
            Mustache.render layout.to_sym, context.merge( { yield: inner } )
        else
            inner
        end
    end

    # For given tmp file and destination root, get the destination file's path
    #
    def self.content_path tmp_filename, target_root_path

        # Note: Stripping '.mustache' from filename and not adding anything.
        # Implication: View file names must include the target file extension.
        path = Filesystem.new_path(
            tmp_filename, Filesystem::SRC_PATH, target_root_path
            ).to_s.gsub( %r{\.mustache$}, '' )

        # Note: Not altering path for a 'clean urls' option. Doing this would
        # require knowing whether the target file is html or something else.
        # Could add this functionality if we could also add view-specific
        # metadata. This could be done with a small amount of code to add
        # frontmatter to mustache files...
        # src/*.X.mustache (w/ fm) -> tmp/*.X.mustache (w/o fm) -> dst/*.X
    end

    # Write preview and (possibly) published files for the given content.
    #
    def self.write_output_files status, item, file_content

        target_root_path =
            case status
            when :preview
                Filesystem::PREVIEW_PATH
            when :published
                Filesystem::PUBLISHED_PATH
            else
                src_filename = item[:src_filename] # Workaround for broken indent https://github.com/codemirror/CodeMirror/issues/3365
                raise "Unknown status (#{status}) for view (#{src_filename})."
            end

        Filesystem.write_file(
            content_path( item[:src_filename], target_root_path ),
            file_content
            )
    end

    public

    # Select all view files and render them to create pages.
    # Write the pages to destination directories.
    #
    def self.inflate metadata

        metadata.select { |m| m[:file_type] == :view }.each do | properties |
            write_output_files(
                :preview, properties, render_view( :preview, properties, metadata )
                )
            write_output_files(
                :published, properties, render_view( :published, properties, metadata )
                )
        end
    end
end


# Ensure that a given directory exists and is empty (except for hidden files in
# the directory root.)
#
def prepare_target dir
    if File.exists? dir
        if File.directory? dir
            # delete everything in dir except hidden things
            FileUtils.rm_rf Dir.glob "#{dir}/*"
        else
            File.delete dir
            Dir.mkdir dir
        end
    else
        Dir.mkdir dir
    end
end




prepare_target  Filesystem::PUBLISHED_ROOT_DIR
prepare_target  Filesystem::PREVIEW_ROOT_DIR
prepare_target  Filesystem::TMP_DIR

# Did user just want to clean build directories?
exit if ARGV.include? 'clean'

metadata = MetadataScraper.scrape Filesystem::SRC_ROOT_DIR
puts metadata if ARGV.include? 'verbose'

MarkdownProcessor.process metadata
AssetCopier.copy metadata
ContentInflator.inflate metadata
ViewsInflator.inflate metadata
