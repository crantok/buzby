# Code Structure

The app is divided in to a set of processors. The first processor scrapes metadata from the source directory tree, creating one metadata hash per file. Subsequent processors read the metadata hashes, write relevant temporary or destination files, and update the metadata hashes appropriately.

The processors in order of use are...

##MetadataScraper
The metadata scraping processor extracts metadata from multiple sources, all of which (apart from "Global" metadata) are sought in the source directory (`./src` by default). Any user-defined metadata can include a metadatum to say whether parent metadata (i.e. metadata from a containing directory) is inherited. The default is to inherit. Metadata sources are:

* Global - Not actually scraped from anywhere. These are global defaults defined in build.rb
* Directory - Any YAML files (.yml) in a directory are treated as metadata applying to that directory. Files are not read in any particular order, so behaviour is not defined when the same key is used in multiple files.
* Content - These are markdown (MD) files. They may have metadata in their frontmatter.
* Views - These are mustache (.mustache) files. They are not read for metadata although their existence is recorded as metadata so that they can be rendered later.
* Anything else - All other files are assumed to be assets. Their existence is recorded. They are not read for metadata.

## MarkdownProcessor
The markdown processor selects all the content files from the metadata and converts their markdown to html fragments, which are saved in the tmp directory. This processor may add a teaser to the metadata for a given piece of content. The teaser won't have beeen available until the content was processed, unless the user specified a teaser in the file-level metadata. The filename from the tmp directory is added to the metadata.

## AssetCopier
Copies assets files to their destination directories. The destination filenames are added to the metadata.

## ContentInflator
Uses mustache templates and layouts to inflate pieces of content in to full html pages. The pages are saved in the preview directory and (if appropriate) the published directory. The destination filenames are added to the metadata.

## ViewInflator
Finally, the view inflator renders any mustache files from the source directory tree and adds them to the published and preview directories.
