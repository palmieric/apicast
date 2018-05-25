local URLRewriting = require('apicast.policy.url_rewriting')

describe('URL rewriting policy', function()
  describe('.rewrite', function()
    before_each(function()
      ngx.var = { uri = '/some_path/to_be_replaced/123/to_be_replaced' }

      stub(ngx.req, 'set_uri', function(new_uri)
        ngx.var.uri = new_uri
      end)

      stub(ngx.req, 'get_uri_args', function() return {} end)
      stub(ngx.req, 'set_uri_args')
    end)

    it('can rewrite URLs using sub', function()
      local config_with_sub = {
        commands = {
          { op = 'sub', regex = 'to_be_replaced', replace = 'new' }
        }
      }
      local url_rewriting = URLRewriting.new(config_with_sub)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri).was_called_with('/some_path/new/123/to_be_replaced')
    end)


    it('can rewrite URLs using gsub', function()
      local config_with_gsub = {
        commands = {
          { op = 'gsub', regex = 'to_be_replaced', replace = 'new' }
        }
      }
      local url_rewriting = URLRewriting.new(config_with_gsub)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri).was_called_with('/some_path/new/123/new')
    end)

    it('applies the commands in order', function()
      local config_with_several_ops = {
        commands = {
          { op = 'gsub', regex = 'to_be_replaced', replace = 'abc' },
          { op = 'gsub', regex = 'abc', replace = 'def' },
          { op = 'gsub', regex = 'def', replace = 'ghi' }
        }
      }
      local url_rewriting = URLRewriting.new(config_with_several_ops)

      url_rewriting:rewrite()

      assert.equals('/some_path/ghi/123/ghi', ngx.var.uri)
    end)

    it('when there is a break, stops at the first match', function()
      local config_with_break = {
        commands = {
          { op = 'gsub', regex = 'to_be_replaced', replace = 'abc', ['break'] = true },
          { op = 'gsub', regex = 'abc', replace = 'def' } -- Not applied
        }
      }
      local url_rewriting = URLRewriting.new(config_with_break)

      url_rewriting:rewrite()

      assert.equals('/some_path/abc/123/abc', ngx.var.uri)
    end)

    it('accepts options for the regexes, same as ngx.req.{sub, gsub}', function()
      local config_with_regex_opts = {
        commands = {
          { op = 'gsub', regex = 'TO_BE_REPLACED', replace = 'new', options = 'i' }
        }
      }
      local url_rewriting = URLRewriting.new(config_with_regex_opts)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri).was_called_with('/some_path/new/123/new')
    end)

    it('can apply the "push" operation to args in the query', function()
      stub(ngx.req, 'get_uri_args', function()
        return { an_arg = '1'}
      end)

      local config_to_push_args = {
        query_args_commands = {
          { op = 'push', arg = 'an_arg', value = '2' }
        }
      }
      local url_rewriting = URLRewriting.new(config_to_push_args)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri_args).was_called_with({ an_arg = { '1', '2' } })
    end)

    it('can apply the "set" operation to args in the query', function()
      stub(ngx.req, 'get_uri_args', function()
        return { an_arg = 'original_value'}
      end)

      local config_to_set_args = {
        query_args_commands = {
          { op = 'set', arg = 'an_arg', value = 'new_val' }
        }
      }
      local url_rewriting = URLRewriting.new(config_to_set_args)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri_args).was_called_with({ an_arg = 'new_val' })
    end)

    it('can apply the "add" operation to args in the query', function()
      stub(ngx.req, 'get_uri_args', function()
        return { an_arg = '1'}
      end)

      local config_to_add_args = {
        query_args_commands = {
          { op = 'add', arg = 'an_arg', value = '2' }
        }
      }
      local url_rewriting = URLRewriting.new(config_to_add_args)

      url_rewriting:rewrite()

      assert.stub(ngx.req.set_uri_args).was_called_with({ an_arg = { '1', '2' } })
    end)

    it('supports liquid templates when pushing query args', function()
      local context = { var_in_context = '123' }

      local config_with_liquid = {
        query_args_commands = {
          {
            op = 'push',
            arg = 'an_arg',
            value = '{{ var_in_context }}',
            value_type = 'liquid'
          }
        }
      }

      local url_rewriting = URLRewriting.new(config_with_liquid)

      url_rewriting:rewrite(context)

      assert.stub(ngx.req.set_uri_args).was_called_with(
        { an_arg = context.var_in_context })
    end)

    it('supports liquid templates when setting query args', function()
      local context = { var_in_context = '123' }

      local config_with_liquid = {
        query_args_commands = {
          {
            op = 'set',
            arg = 'an_arg',
            value = '{{ var_in_context }}',
            value_type = 'liquid'
          }
        }
      }

      local url_rewriting = URLRewriting.new(config_with_liquid)

      url_rewriting:rewrite(context)

      assert.stub(ngx.req.set_uri_args).was_called_with(
        { an_arg = context.var_in_context })
    end)

    it('supports liquid templates when adding query args', function()
      local context = { var_in_context = '123' }

      local config_with_liquid = {
        query_args_commands = {
          {
            op = 'add',
            arg = 'an_arg',
            value = '{{ var_in_context }}',
            value_type = 'liquid'
          }
        }
      }

      local url_rewriting = URLRewriting.new(config_with_liquid)

      url_rewriting:rewrite(context)

      assert.stub(ngx.req.set_uri_args).was_called_with(
        { an_arg = { 'original_value', context.var_in_context } })
    end)
  end)
end)
