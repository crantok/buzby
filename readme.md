# Buzby (the Bloody Small Site Builder)

## Why?

Yeah, there are loads of good site builders out there (I'm told) so why did I write another one? Well, why do we write any software? I thought it would be as quick to write my own site builder and incrementally add features as it would be to learn the interface of an existing one and the work arounds to get it to do whatever uncommon things I would eventually want.

Also, as you'll see if you poke around the code, it's pretty small. My intention was to keep things simple and small enough for features to be hacked in per project (rather than implementing generic ways of plugging in to the build process.) Ooh, I like that: "It's not a plugin architecture, it's a hack-in architecture."

Buzby is so small that it makes me think that writing a static site builder might be a good first or second non-trivial coding project.

## What?

Not a lot really. That was deliberate. I wanted to implement the minimum that would satisfy me...

### Metadata
I wrote a mechanism to cascade metadata down from parent to child directories and then to files, and a way to stop that inheritance of metadata at any stage. All the metadata is in YAML. Metadata specific to a piece of content is contained in its Frontmatter. This means that you can toggle flags and add tags at any level, and then use this information in your views and templates. I think I spent the most time on this part so either it seemed like the most important bit to me or it was the trickiest.

### Markdown content
Buzby is a way of allowing content curators to manage their content as markdown files. The file format is not optional in the way I have written the script.  You could always hack the script to change this if you like the rest of what you see.

### Mustache views and templates
Ditto for hacking this if you don't like Mustache. (I love it for getting html-savvy designers to change their designs in-place rather than going through me.)

Views are rendered relative to where they are in the source tree. The final file has the same name as the view but with the ".mustache" chopped off. This means you can generate any kind of file from a view (.xml, .php, etc) not just html.

Templates live in the template directory and are used to arrange content and to wrap it in a layout.

### Assets
All files in the source directory that are not mentioned above are assumed to be assets and are just copied straight over to the output directories.

### Clean URLs
There is a flag in the metadata (clean_urls, `true` by default) that creates directories containing files called index.html in the output directory structure. Years of working with Drupal would not allow me to leave this out.

### Preview and published
There are two output directories (./preview and ./published). All content is put in the ./preview directory. Only content that is marked as 'published' in its metadata is put in the ./published directory.

## How?

### Prerequisites
* Ruby
* Bundler (for an easy life)

### Installation

* Clone the repo or download as an archive and extract the files.
* From the root of the cloned/extracted directory tree: `bundle`

### Building

* Make sure the current directory is the root of Buzby's directory tree.
* To build the site(s): `ruby build.rb`
* To remove intermediate and output directories: `ruby build.rb clean`

Buzby currently executes the `clean` at the beginning of the site build. I just extracted it as a separate command for debugging purposes.

### Creating content

Put markdown files (.md) in the ./src directory. They'll appear as html files in the relevant output directories. By default they'll have a clean URL. Set `content_type` in their metadata to identify the template to use with them. (You might want to do this at a directory level.) Set `published` in their metadata to have them appear in the published site.

### Presenting content

The mustache templates will receive content of the processed markdown file as a variable called `content`. All other variables refer to other relevant metadata.

Mustache layouts (default_layout.mustache being the default) receive the page content in variable called `yield`. All other variables refer to other metadata.

### Adding views

Put a mustache file (.mustache) in the ./src directory. Its inputs will be the collected metadata processed through view.rb. Modify view.rb to change the input available to your views.

## Help?

* See the [./docs directory](https://github.com/crantok/buzby/tree/master/docs) for a bit more info.
* See the [example site](https://github.com/crantok/buzby-example) repo to see Buzby in action.
* If you find a bug or have a feature request then [open an issue](https://github.com/crantok/buzby/issues) on Github.
* If you want more help then please [ask on Stackoverflow](http://stackoverflow.com/questions/ask?tags=buzby) with a tag of `buzby`. (That link should include the tag automatically.) I can't subscribe to the tag yet because no one has asked a question, so if you're the first then please [open an issue](https://github.com/crantok/buzby/issues) on Github to get my attention.

## How I use Buzby

I don't keep the ./src directory in my git repo. I just add a symbolic link to a shared Dropbox directory and point content curators at that. If I'm using Buzby then I'm building a relatively simple site and the curators will include people who are not tech-savvy and who would be intimidated by a CMS, so I definitely don't want to teach them git. Open-file-edit-file-save-file-done. That's what I was aiming for. Then I just have the server rebuild the site every time there is a change in the dropbox directory. Obviously, curators have to explicitly mark content for it to appear in the published site.

## Contributing
I'm happy to assess contributions and incorporate what I think is useful. Just remember that my main intent is to keep things simple and small enough to be hacked per project. If you want to discuss it first then feel free to open an issue. If you have something you want me to consider then please; fork the [canonical repo](github.com/crantok/buzby), branch from master, commit your stuff, submit a pull request, make yourself a nice cup of tea.
