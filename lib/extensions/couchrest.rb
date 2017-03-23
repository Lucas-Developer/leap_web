module CouchRest
  module Model
    class Base
      extend ActiveModel::Naming
      extend ActiveModel::Translation
    end
    module Designs

      class View

        # so we can called Ticket.method.descending or Ticket.method.ascending
        def ascending
          self
        end
      end

      class DesignMapper
        DEFAULT_REDUCE = <<-EOJS
          function(key, values, rereduce) {
            return sum(values);
          }
          EOJS
        def load_views(dir, reduce=DEFAULT_REDUCE)
          Dir.glob("#{dir}/*.js") do |js|
            name = File.basename(js, '.js')
            file = File.open(js, 'r')
            view name.to_sym,
              map: file.read,
              reduce: reduce
          end
        end
      end
    end

    module Utils
      module Migrate
        def self.load_all_models_with_engines
          self.load_all_models_without_engines
          return unless defined?(Rails)
          Dir[Rails.root + 'engines/*/app/models/**/*.rb'].each do |path|
            require path
          end
        end

        class << self
          alias_method_chain :load_all_models, :engines
        end

        def dump_all_models
          prepare_directory
          find_models.each do |model|
            model.design_docs.each do |design|
              dump_design(model, design)
            end
          end
        end

        protected

        def dump_design(model, design)
          dir = prepare_directory model.name.tableize
          filename = design.id.sub('_design/','') + '.json'
          puts dir + filename
          design.checksum
          File.open(dir + filename, "w") do |file|
            file.write(JSON.pretty_generate(design.to_hash))
          end
        end

        def prepare_directory(dir = '')
          dir = Rails.root + 'tmp' + 'designs' + dir
          Dir.mkdir(dir) unless Dir.exist?(dir)
          return dir
        end

      end
    end

  end

end
