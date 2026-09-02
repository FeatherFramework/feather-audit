_G.TestAssert = dofile('tests/support/bootstrap.lua')
_G.TestFixtures = dofile('tests/support/fixtures.lua')

local specifications = {
    'tests/unit/canonical_spec.lua',
    'tests/unit/validator_spec.lua',
    'tests/unit/builder_spec.lua',
    'tests/unit/config_spec.lua',
    'tests/integration/outbox_harness_spec.lua',
    'tests/unit/ingestion_service_spec.lua'
}

local passed = 0
for _, path in ipairs(specifications) do
    io.write(('RUN %s\n'):format(path))
    local ok, err = pcall(dofile, path)
    if not ok then
        io.stderr:write(('FAIL %s\n%s\n'):format(path, tostring(err)))
        os.exit(1)
    end
    passed = passed + 1
end

io.write(('PASS %d specifications\n'):format(passed))
