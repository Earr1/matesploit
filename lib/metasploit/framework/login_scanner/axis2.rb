
require 'metasploit/framework/login_scanner/http'

module Metasploit
  module Framework
    module LoginScanner

      # Tomcat Manager login scanner
      class Axis2 < HTTP

        DEFAULT_PORT = 8080
        # Inherit LIKELY_PORTS,LIKELY_SERVICE_NAMES, and REALM_KEY from HTTP

        CAN_GET_SESSION = true
        PRIVATE_TYPES   = [ :password ]

        # (see Base#attempt_login)
        def attempt_login(credential)
          result_opts = {
              credential: credential,
              host: host,
              port: port,
              protocol: 'tcp'
          }
          if ssl
            result_opts[:service_name] = 'https'
          else
            result_opts[:service_name] = 'http'
          end

          begin
            # Refactor to access Metasploit::Framework::LoginScanner::HTTP#send_request()
            # to send request to the HTTP server and obtain a response
            response = send_request({
              'uri' => uri,
              'method' => 'POST',
              'vars_post' =>
               {
                 'userName' => credential.public,
                 'password' => credential.private,
                 'submit' => '+Login+'
               }
            })

            if response && response.code == 200 && response.body.include?("upload")
              result_opts.merge!(status: Metasploit::Model::Login::Status::SUCCESSFUL, proof: response)
            else
              result_opts.merge!(status: Metasploit::Model::Login::Status::INCORRECT, proof: response)
            end
          rescue ::EOFError, Rex::ConnectionError, ::Timeout::Error => e
            result_opts.merge!(status: Metasploit::Model::Login::Status::UNABLE_TO_CONNECT, proof: e)
          end

          Result.new(result_opts)

        end

        # (see Base#set_sane_defaults)
        def set_sane_defaults
          self.uri = "/axis2/axis2-admin/login" if self.uri.nil?
          @method = "POST".freeze

          super
        end

        # The method *must* be "POST", so don't let the user change it
        # @raise [RuntimeError]
        def method=(_)
          raise RuntimeError, "Method must be POST for Axis2"
        end

      end
    end
  end
end

