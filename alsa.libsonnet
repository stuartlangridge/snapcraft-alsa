function(version="") {
    local apps = (
        if "apps" in super then super.apps
        else {}
    ),
    local parts = (
        if "parts" in super then super.parts
        else {}
    ),

    layout+: (
        if version == "" then
            {
                "/usr/lib/$SNAPCRAFT_ARCH_TRIPLET/alsa-lib": {
                    bind: "$SNAP/usr/lib/$SNAPCRAFT_ARCH_TRIPLET/alsa-lib"
                },
            }
        else
            {
                "/usr/lib/alsa-lib": {
                    bind: "$SNAP/usr/lib/alsa-lib"
                },
            }
    ),

    apps: std.mapWithKey(function(name, app) (
        app + {
            "command-chain": std.setUnion((
                if std.objectHas(app, 'command-chain') then
                    app['command-chain']
                else []
            ), ['snap/command-chain/alsa-launch']),
            plugs: std.setUnion((
                if std.objectHas(app, 'plugs') then
                    app.plugs
                else []
            ), ["pulseaudio"])
        }
    ), apps),

    parts: std.mapWithKey(function(name, part) (
        part + {
            "build-packages": (
                if std.objectHas(part, 'build-packages') then
                    std.filter(
                        function(package) (package != "libasound2-dev"),
                        part["build-packages"]
                    )
                else []
            ),
            "stage-packages": (
                if std.objectHas(part, 'stage-packages') then
                    std.filter(
                        function(package) (
                            package != "libasound2" &&
                            package != "libasound2-plugins"
                        ),
                        part["stage-packages"]
                    )
                else []
            ),
            stage: std.setUnion((
                if std.objectHas(part, 'stage') then
                    part.stage
                else []
            ), [
                "-usr/share/alsa",
                "-usr/lib/$SNAPCRAFT_ARCH_TRIPLET/alsa-lib",
                "-usr/lib/$SNAPCRAFT_ARCH_TRIPLET/libasound*"
            ]),
            after: std.setUnion((
                if std.objectHas(part, 'after') then
                    part.after
                else []
            ), ["alsa-mixin"]),
        }
    ), super.parts) + {
        "alsa-mixin": {
            source: "https://github.com/diddledan/snapcraft-alsa.git",
            plugin: "nil",
            "override-pull": |||
                set -eux
                cat > asound.conf <<EOF
                pcm.!default {
                    type pulse
                    fallback "sysdefault"
                    hint {
                        show on
                        description "Default ALSA Output (currently PulseAudio Sound Server)"
                    }
                }
                ctl.!default {
                    type pulse
                    fallback "sysdefault"
                }
                EOF
                cat > alsa-launch <<EOF
                #!/bin/bash
                export ALSA_CONFIG_PATH="\$SNAP/etc/asound.conf"

                if [ -d "\$SNAP/usr/lib/alsa-lib" ]; then
                    export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH:\$SNAP/usr/lib/alsa-lib"
                elif [ -d "\$SNAP/usr/lib/$SNAPCRAFT_ARCH_TRIPLET/alsa-lib" ]; then
                    export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH:\$SNAP/usr/lib/$SNAPCRAFT_ARCH_TRIPLET/alsa-lib"
                fi
                export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH:\$SNAP/usr/lib/$SNAPCRAFT_ARCH_TRIPLET/pulseaudio"

                # Make PulseAudio socket available inside the snap-specific \$XDG_RUNTIME_DIR
                if [ -n "\$XDG_RUNTIME_DIR" ]; then
                    pulsenative="pulse/native"
                    pulseaudio_sockpath="\$XDG_RUNTIME_DIR/../\$pulsenative"
                    if [ -S "\$pulseaudio_sockpath" ]; then
                        export PULSE_SERVER="unix:\${pulseaudio_sockpath}"
                    fi
                fi

                exec "\$@"
                EOF
                chmod +x alsa-launch
            |||,
            "override-build": |||
                set -eux
                install -m644 -D -t "$SNAPCRAFT_PART_INSTALL/etc" asound.conf
                install -m755 -D -t "$SNAPCRAFT_PART_INSTALL/snap/command-chain" alsa-launch
            |||,
            "build-packages": (
                if version == "" then ["libasound2-dev"]
                else []
            ),
            "stage-packages": (
                if version == "" then ["libasound2", "libasound2-plugins"]
                else []
            ),
            after: (
                if version == "" then []
                else ["alsa-lib-mixin", "alsa-plugins-mixin"]
            )
        },
    } + (
        if version == "" then {}
        else {
            "alsa-lib-mixin": {
                plugin: "autotools",
                source: "https://www.alsa-project.org/files/pub/lib/alsa-lib-" + version + ".tar.bz2",
                configflags: ["--prefix=/usr"],
            },
            "alsa-plugins-mixin": {
                after: ["alsa-lib-mixin"],
                plugin: "autotools",
                source: "https://www.alsa-project.org/files/pub/plugins/alsa-plugins-" + version + ".tar.bz2",
                configflags: ["--prefix=/usr"],
                "build-packages": ["libpulse-dev"],
                "stage-packages": ["libpulse0"],
            },
        }
    )
}
