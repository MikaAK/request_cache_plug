# 0.1.14
- Ensure default ttl is applied properly

# 0.1.13
- Add custom labels per endpoint via telemetry metrics

# 0.1.12
- Add telemetry metrics

# 0.1.11
- Fix error messaging
- Make sure cache module gets pulled out of config or the conn opts properly

# 0.1.10
- Add contenttype of application/json to response

# 0.1.9
- Swap to md5 hashing as phash doesn't contain enough range

# 0.1.8
- fix config app not matching app name

# 0.1.7
- fix issue with plug not pulling configured cache

# 0.1.6
- fix issue with plug not pulling ttls out when using absinthe plugs

# 0.1.5
- fix some bugs around resolver usage of store
- add verbose logging when enabled

# 0.1.4
- add debug log when item returned from cache

# 0.1.3
- Stop raising exceptions and log messages in debug mode
- add `enabled?` global config`

# 0.1.2
- Fix the child_spec inside of ConCacheStore

# 0.1.1
- Lower absinthe version requirement

# 0.1.0
- Initial Release
