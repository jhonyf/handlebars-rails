require 'handlebars-rails/version'
require 'handlebars-rails/v8'
require 'active_support'

module Handlebars
  class TemplateHandler

    def self.js_library_path=(js_library_path)
      @js_library_path = js_library_path
    end

    def self.default_js_library_path
      Rails.root + "vendor/javascripts/handlebars.js"
    end

    def self.handlebars
      return @handlebars if @handlebars
      if File.exists?(@handlebars = (@js_library_path || default_js_library_path))
        @handlebars
      else
        raise LoadError, "Could not load Handlebars.js from #{@handlebars}. " <<
          "Change path by setting Handlebars::TemplateHandler.js_library_path"
      end
    end

    def self.js
      Thread.current[:v8_context] ||= begin
        V8::Context.new do |js|
          js.load(handlebars)
          js.eval("Templates = {}")

          js["puts"] = method(:puts)

          js.eval(%{
            Handlebars.registerHelper('helperMissing', function(helper) {
              var params = Array.prototype.slice.call(arguments, 1);
              return actionview[helper].apply(actionview, params);
            })
          })
        end
      end
    end

    def self.call(template)
      # Here, we're sticking the compiled template somewhere in V8 where
      # we can get back to it
      js.eval(%{Templates["#{template.identifier}"] = Handlebars.compile(#{template.source.inspect}) })

      %{
        js = ::Handlebars::TemplateHandler.js
        js['actionview'] = self
        js.eval("Templates['#{template.identifier}']").call(assigns).force_encoding(Encoding.default_external)
      }
    end

  end
end

ActiveSupport.on_load(:action_view) do
  ActionView::Template.register_template_handler(:hbs, ::Handlebars::TemplateHandler)
end
