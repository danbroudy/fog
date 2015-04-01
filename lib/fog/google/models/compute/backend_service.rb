require 'fog/core/model'

module Fog
  module Compute
    class Google
      class BackendService < Fog::Model
        identity :name

        attribute :backends, :aliases => 'backends'
        attribute :creation_timestamp, :aliases => 'kind'
        attribute :description, :aliases => 'description'
        attribute :fingerprint, :aliases => 'fingerprint'
        attribute :health_checks, :aliases => 'healthChecks'
        attribute :id, :aliases => 'id'
        attribute :kind, :aliases => 'kind'
        attribute :port, :aliases => 'port'
        attribute :protocol, :aliases => 'protocol'
        attribute :self_link, :aliases => 'selfLink'
        attribute :timeout_sec, :aliases => 'timeoutSec'

        def save
          requires :name, :health_checks

          # TODO: Question (broudy): should this only accept arrays of health check hashes
          # or should it also accept arrays of selfLinks (aka strings)
          # Should we just ignore multiple health_checks because backends currenly only accept one?

          options = {
            'description' => description,
            'backends' => backends,
            'fingerprint' => fingerprint,
            'healthChecks' => [ health_checks[0].self_link ],
            'port' => port,
            'protocol' => protocol,
            'timeoutSec' => timeout_sec
          }

          # Remove any options where value is null
          options.delete_if { |k, v| v.nil?}

          data = service.insert_backend_service(name, options).body
          operation = Fog::Compute::Google::Operations.new(:service => service).get(data['name'])
          operation.wait_for { !pending? }
          reload
        end

        def destroy(async=false)
          requires :name

          operation = service.delete_backend_service(name)
          unless async
            Fog.wait_for do
              operation.body["status"] == "DONE"
            end
          end
          operation
        end

        def get_health
          service.get_backend_service_health self
        end

        def add_backend backend
          # ensure backend is an array of hashes
          backend = [backend] unless backend.class == Array
          backend.map! { |resource| resource.class == String ? { 'group' => resource }: resource }
          service.add_backend_service_backends(self, backend)
          reload
        end

        def ready?
          begin
            service.get_backend_service(self.name)
            true
          rescue Fog::Errors::NotFound
            false
          end
        end

        def reload
          requires :name

          return unless data =
            begin
              collection.get(name)
            rescue Excon::Errors::SocketError
              nil
            end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end

        RUNNING_STATE = "READY"
      end
    end
  end
end
