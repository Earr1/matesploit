require 'metasploit/framework/login_scanner/http'

module Metasploit
  module Framework
    module LoginScanner

      # IP Board login scanner
      class IPBoard < HTTP

        # @!attribute http_username
        # @return [String]
        attr_accessor :http_username

        # @!attribute http_password
        # @return [String]
        attr_accessor :http_password

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

            nonce_response = send_request({
                'uri' => uri,
                'method'  => 'GET'
            })

            if nonce_response.body =~ /name='auth_key'\s+value='.*?((?:[a-z0-9]*))'/i
              server_nonce = $1

              if uri.end_with? '/'
                base_uri = uri.gsub(/\/$/, '')
              else
                base_uri = uri
              end

              auth_uri = "#{base_uri}/index.php"

              response = send_request({
                'uri' => auth_uri,
                'method'  => 'POST',
                'vars_get' => {
                  'app'     => 'core',
                  'module'  => 'global',
                  'section' => 'login',
                  'do'      => 'process'
                },
                'vars_post'      => {
                  'auth_key'     => server_nonce,
                  'ips_username' => credential.public,
                  'ips_password' => credential.private
                }
              })

              if response && response.get_cookies.include?('ipsconnect') && response.get_cookies.include?('coppa')
                result_opts.merge!(status: Metasploit::Model::Login::Status::SUCCESSFUL, proof: response)
              else
                result_opts.merge!(status: Metasploit::Model::Login::Status::INCORRECT, proof: response)
              end

            else
              result_opts.merge!(status: Metasploit::Model::Login::Status::UNABLE_TO_CONNECT, proof: "Server nonce not present, potentially not an IP Board install or bad URI.")
            end
          rescue ::EOFError, Rex::ConnectionError, ::Timeout::Error => e
            result_opts.merge!(status: Metasploit::Model::Login::Status::UNABLE_TO_CONNECT, proof: e)
          end

          Result.new(result_opts)

        end


        # (see Base#set_sane_defaults)
        def set_sane_defaults
          self.uri = "/forum/" if self.uri.nil?
          @method = "POST".freeze

          super
        end

        # The method *must* be "POST", so don't let the user change it
        # @raise [RuntimeError]
        def method=(_)
          raise RuntimeError, "Method must be POST for IPBoard"
        end

      end
    end
  end
end

