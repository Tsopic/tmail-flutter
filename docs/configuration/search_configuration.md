## Configuration Server Search

### Context
- The default search sort, **Relevance**, sends no sort to `Email/query` and
  lets the server rank the matches.
- Some JMAP servers do not rank. Stock Stalwart, for example, returns unsorted
  matches oldest first, so Relevance would list the oldest mail first.

### How to config
In [env.file]:
- For a server that ranks matches when no sort is sent (default):
```SERVER_SEARCH=ranked```
    or remove the key.
- For a server that does not:
```SERVER_SEARCH=basic```

With `basic`, Relevance sorts by received date, newest first, and pages by
date like **Most recent**. Search filters and the other sort orders are
unchanged.

Values are case-insensitive. Any value other than `basic` means `ranked`.

### Platforms
- Web reads `env.file` at startup, so the option can change per deployment
  without a rebuild.
