module MediaWiki

  class Gateway

    module Users

      # Login to MediaWiki
      #
      # [username] Username
      # [password] Password
      # [domain] Domain for authentication plugin logins (eg. LDAP), optional -- defaults to 'local' if not given
      # [options] Hash of additional options
      #
      # Throws MediaWiki::Unauthorized if login fails
      def login(username, password, domain = 'local', options = {})
        send_request(options.merge(
          'action'     => 'login',
          'lgname'     => username,
          'lgpassword' => password,
          'lgdomain'   => domain
        ))

        @password = password
        @username = username
      end

      # Get a list of users
      #
      # [options] Optional hash of options, eg. { 'augroup' => 'sysop' }.  See http://www.mediawiki.org/wiki/API:Allusers
      #
      # Returns array of user names (empty if no matches)
      def users(options = {})
        iterate_query('allusers', '//u', 'name', 'aufrom', options.merge(
          'aulimit' => @options[:limit]
        ))
      end

      # Get user contributions
      #
      # [user] The user name
      # [count] Maximum number of contributions to retrieve, or nil for all
      # [options] Optional hash of options, eg. { 'ucnamespace' => 4 }.  See http://www.mediawiki.org/wiki/API:Usercontribs
      #
      # Returns array of hashes containing the "item" attributes defined here: http://www.mediawiki.org/wiki/API:Usercontribs
      def contributions(user, count = nil, options = {})
        result = []

        iterate_query('usercontribs', '//item', nil, 'uccontinue', options.merge(
          'ucuser'  => user,
          'uclimit' => @options[:limit]
        )) { |element|
          result << hash = {}
          element.attributes.each { |key, value| hash[key] = value }
          break if count && result.size >= count
        }

        count ? result.take(count) : result
      end

      # Sends e-mail to a user
      #
      # [user] Username to send mail to (name only: eg. 'Bob', not 'User:Bob')
      # [subject] Subject of message
      # [content] Content of message
      # [options] Hash of additional options
      #
      # Will raise a 'noemail' APIError if the target user does not have a confirmed email address, see http://www.mediawiki.org/wiki/API:E-mail for details.
      def email_user(user, subject, text, options = {})
        res = send_request(options.merge(
          'action'  => 'emailuser',
          'target'  => user,
          'subject' => subject,
          'text'    => text,
          'token'   => get_token('email', "User:#{user}")
        ))

        res.elements['emailuser'].attributes['result'] == 'Success'
      end

      # Create a new account
      #
      # [options] is +Hash+ passed as query arguments. See https://www.mediawiki.org/wiki/API:Account_creation#Parameters for more information.
      def create_account(options)
        send_request(options.merge('action' => 'createaccount'))
      end

      # Sets options for currenlty logged in user
      #
      # [changes] a +Hash+ that will be transformed into an equal sign and pipe-separated key value parameter
      # [optionname] a +String+ indicating which option to change (optional)
      # [optionvalue] the new value for optionname - allows pipe characters (optional)
      # [reset] a +Boolean+ indicating if all preferences should be reset to site defaults (optional)
      # [options] Hash of additional options
      def options(changes = {}, optionname = nil, optionvalue = nil, reset = false, options = {})
        form_data = options.merge(
          'action' => 'options',
          'token'  => get_options_token
        )

        if changes && !changes.empty?
          form_data['change'] = changes.map { |key, value| "#{key}=#{value}" }.join('|')
        end

        if optionname && !optionname.empty?
          form_data[optionname] = optionvalue
        end

        if reset
          form_data['reset'] = true
        end

        send_request(form_data)
      end

      # Set groups for a user
      #
      # [user] Username of user to modify
      # [groups_to_add] Groups to add user to, as an array or a string if a single group (optional)
      # [groups_to_remove] Groups to remove user from, as an array or a string if a single group (optional)
      # [options] Hash of additional options
      def set_groups(user, groups_to_add = [], groups_to_remove = [], comment = '', options = {})
        token = get_userrights_token(user)
        userrights(user, token, groups_to_add, groups_to_remove, comment, options)
      end

      private

      # User rights management (aka group assignment)
      def get_userrights_token(user)
        res = send_request(
          'action'  => 'query',
          'list'    => 'users',
          'ustoken' => 'userrights',
          'ususers' => user
        )

        token = res.elements['query/users/user'].attributes['userrightstoken']

        @log.debug("RESPONSE: #{res.to_s}")

        unless token
          if res.elements['query/users/user'].attributes['missing']
            raise APIError.new('invaliduser', "User '#{user}' was not found (get_userrights_token)")
          else
            raise Unauthorized.new("User '#{@username}' is not permitted to perform this operation: get_userrights_token")
          end
        end

        token
      end

      def get_options_token
        send_request('action' => 'tokens', 'type' => 'options')
          .elements['tokens'].attributes['optionstoken']
      end

      def userrights(user, token, groups_to_add, groups_to_remove, reason, options = {})
        # groups_to_add and groups_to_remove can be a string or an array. Turn them into MediaWiki's pipe-delimited list format.
        if groups_to_add.is_a?(Array)
          groups_to_add = groups_to_add.join('|')
        end

        if groups_to_remove.is_a?(Array)
          groups_to_remove = groups_to_remove.join('|')
        end

        send_request(options.merge(
          'action' => 'userrights',
          'user'   => user,
          'token'  => token,
          'add'    => groups_to_add,
          'remove' => groups_to_remove,
          'reason' => reason
        ))
      end

    end

    include Users

  end

end
