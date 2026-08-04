[
  (final: prev: {
    yt-dlp =
      (prev.yt-dlp.override {
        ffmpegSupport = false;
        atomicparsleySupport = false;
        rtmpSupport = false;
        withSecretStorage = false;
        jsRuntime = final.quickjs-ng;
      }).overridePythonAttrs (old: {
        dependencies =
          builtins.filter (
            dependency:
              (dependency.pname or "") != "curl-cffi"
          )
          old.dependencies;

        # This is not strictly required for the runtime closure because
        # `dependencies` above is what gets propagated. It keeps the
        # derivation's exposed optional-dependency metadata consistent.
        optional-dependencies =
          old.optional-dependencies
          // {
            curl-cffi = [];
          };
      });
  })
]
