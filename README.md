# Deluge CI Toolchains

This repository has tools for building (and uploading to the Github Container
Registry) ubuntu-based docker images that package the [Deluge Build Tools
toolchain]. To use them locally, this snippet should work (run within the
[DelugeFirwmare] repository):

```shell
docker run --rm \
    --user=$(id --user):$(id --group) \
    -v $(pwd):$(pwd) \
    --workdir $(pwd) \
    --entrypoint $(pwd)/dbt \
    ghcr.io/bobtwinkles/deluge-ci-images:main \
    --e2_target=dbt-build-release-oled
```

# Development
This repository is set up to automatically publish images to GHCR on push. For
local development, there's some support for locally downloaded versions of the
toolchains. Check the `Dockerfile` for the `COPY` command to uncomment for
that.


[DelugeFirmware]: https://github.com/SynthstromAudible/DelugeFirmware/
[Deluge Build Tools toolchain]: https://github.com/litui/dbt-toolchain
