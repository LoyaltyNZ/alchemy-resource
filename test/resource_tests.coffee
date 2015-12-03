describe 'Resource', ->
  describe '#matches_path', ->
    it 'should match a variety of paths', ->
      test_strings = ['v1/users', '/v1/users', '/v1/users/', 'v1/users/']
      resources = []
      for ts in test_strings
       resources.push new Resource('test', ts)
      test_strings.push 'v1/users/1'
      test_strings.push 'v1/users/1/'
      test_strings.push '/v1/users/1'
      test_strings.push '/v1/users/1/'

      for ts in test_strings
        for res in resources
          expect(res.matches_path(ts)).to.equal true
