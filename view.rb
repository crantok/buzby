# A class to render view templates.
#
# I thought about allowing an individual Mustache-derived class per view but
# wasn't sure how to rationalise the template and class system. My solution is
# to have a single Mustache-derived companion class to handle data for all
# views.

require 'mustache'


class View < Mustache

    def render context
        process_context context
        super context
    end

    private

    # Modify the context here, i.e. add everything required for your views.
    #
    # CONVENTION: Examine context[:status] to determine whether this view
    # is being published or previewed (or is targeted at an as-yet-unknown
    # state.)
    #
    def process_context context

        # Add your own data organisation here

        # If you wish, you can examine context[:src_filename] to determine
        # which view you are preparing. Alternatively, you can just give
        # every view an identical context.

        add_content_items_to_collections context
    end


    # Add collections of content items to the context.
    # One collection per content-type.
    # Only include items accessible in the current context status.
    #
    def add_content_items_to_collections context

        context[:all_metadata].select do |item|
            item[:file_type] == :content  && (
                context[:status] == :preview  ||  item['published'] )
        end.each do | item |
            context[( item['content_type'] + 's').to_sym ] ||= []
            context[( item['content_type'] + 's').to_sym ].push item
        end
    end
end
