local Executor = require('resty.concurrent.executor')
local ImmediateExecutor = require('resty.concurrent.immediate_executor')

describe('ImmediateExecutor', function()
    describe('.from_options', function()
        it('works with empty table', function()
            assert(Executor.from_options{ })
        end)

        it('works with nil', function()
            assert(Executor.from_options())
        end)

        it('returns default executor', function()
            assert.equal(ImmediateExecutor, Executor.from_options())
        end)

        it('works with string', function()
            assert.equal(ImmediateExecutor, Executor.from_options{ executor = 'immediate'})
        end)

        it('throws error on unknown executor', function()
            assert.has_error(function()
                Executor.from_options{ executor = '_invalid_'}
            end, 'unknown executor: _invalid_')
        end)

        it('has passes through executor', function()
            local executor = { 'something' }

            assert.equal(executor, Executor.from_options{ executor = executor })
        end)
    end)
end)
