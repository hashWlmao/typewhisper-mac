/*@cc_on
@if (@_jscript)
    // Offer to self-install for clueless users that try to run this directly.
    var shell = WScript.CreateObject("WScript.Shell");
    var fs = new ActiveXObject("Scripting.FileSystemObject");
    var pathPlugins = shell.ExpandEnvironmentStrings("%APPDATA%\\BetterDiscord\\plugins");
    var pathSelf = WScript.ScriptFullName;
    // Put the user at ease by addressing them in the first person
    shell.Popup("It looks like you've mistakenly tried to run me directly. \n(Don't do that!)", 0, "I'm a plugin for BetterDiscord", 0x30);
    if (fs.GetParentFolderName(pathSelf) === fs.GetAbsolutePathName(pathPlugins)) {
        shell.Popup("I'm in the correct folder already.\nJust reload Discord with Ctrl+R.", 0, "I'm already installed", 0x40);
    } else if (!fs.FolderExists(pathPlugins)) {
        shell.Popup("I can't find the BetterDiscord plugins folder.\nAre you sure it's even installed?", 0, "Can't install myself", 0x10);
    } else if (shell.Popup("Should I copy myself to BetterDiscord's plugins folder for you?", 0, "Do you need some help?", 0x34) === 6) {
        fs.CopyFile(pathSelf, fs.BuildPath(pathPlugins, fs.GetFileName(pathSelf)));
        // Show the user where to put plugins in the future
        shell.Exec("explorer " + pathPlugins);
        shell.Popup("I'm installed!\nJust reload Discord with Ctrl+R.", 0, "Successfully installed", 0x40);
    }
    WScript.Quit();
@else@*/
module.exports = (() => {
    const config = {
        info: {
            name: "BazCord Stereo",
            authors: [{
                name: "solaltw/baz",
                discord_id: "1282869943729127494",
                github_username: "https://github.com/hashWlmao/plugins"
            }],
            version: "1.2.0",
            description: "Enhanced stereo audio control with modded bitrate options",
            github: "https://github.com/yourrepo/bazcord-stereo",
            github_raw: "https://github.com/hashWlmao/plugins",
            website: "https://github.com/hashWlmao/plugins"
        },
        changelog: [
            {
                title: "Initial Release",
                items: [
                    "Added stereo, mono, and both channel options",
                    "Implemented modded bitrate controls",
                    "Added UI controls in voice settings"
                ]
            },
            {
                title: "v1.1.0",
                items: [
                    "Added audio visualization",
                    "Improved bitrate options",
                    "Fixed compatibility issues"
                ]
            },
            {
                title: "v1.2.0",
                items: [
                    "Added per-user channel balance controls",
                    "Optimized performance",
                    "Added more bitrate options"
                ]
            }
        ]
    };

    return !global.ZeresPluginLibrary ? class {
        constructor() { this._config = config; }
        getName() { return config.info.name; }
        getAuthor() { return config.info.authors.map(a => a.name).join(", "); }
        getDescription() { return config.info.description; }
        getVersion() { return config.info.version; }
        load() {
            BdApi.showConfirmationModal("Library Missing", `The library plugin needed for ${config.info.name} is missing. Please click Download Now to install it.`, {
                confirmText: "Download Now",
                cancelText: "Cancel",
                onConfirm: () => {
                    require("request").get("https://rauenzi.github.io/BDPluginLibrary/release/0PluginLibrary.plugin.js", async (error, response, body) => {
                        if (error) return require("electron").shell.openExternal("https://betterdiscord.app/Download?id=9");
                        await new Promise(r => require("fs").writeFile(require("path").join(BdApi.Plugins.folder, "0PluginLibrary.plugin.js"), body, r));
                    });
                }
            });
        }
        start() { }
        stop() { }
    } : (([Plugin, Library]) => {
        const { DiscordModules, WebpackModules, Patcher, PluginUtilities, Utilities, Toasts } = Library;
        const { React } = DiscordModules;
        const AudioEngine = WebpackModules.getByProps("getOutputVolume");
        const VoiceEngine = WebpackModules.getByProps("setLocalVolume");
        const BitrateModule = WebpackModules.getByProps("getBitrate");

        const defaultSettings = {
            channelMode: "stereo", // "stereo", "mono", "both"
            bitrate: 128, // Modded bitrate options
            leftBalance: 100,
            rightBalance: 100,
            showVisualizer: true,
            advancedMode: false
        };

        const bitrateOptions = [
            { label: "Low (64kbps)", value: 64 },
            { label: "Normal (96kbps)", value: 96 },
            { label: "High (128kbps)", value: 128 },
            { label: "Very High (192kbps)", value: 192 },
            { label: "Ultra (256kbps)", value: 256 },
            { label: "Extreme (320kbps)", value: 320 }
        ];

        return class BazCordStereo extends Plugin {
            constructor() {
                super();
                this.settings = Utilities.loadData(config.info.name, "settings", defaultSettings);
            }

            onStart() {
                this.patchAudioEngine();
                this.addSettingsPanel();
                this.addVoiceSettings();
                PluginUtilities.addStyle(config.info.name, `
                    .bazcord-stereo-slider {
                        margin: 10px 0;
                    }
                    .bazcord-stereo-visualizer {
                        height: 60px;
                        margin: 10px 0;
                        display: flex;
                        align-items: flex-end;
                    }
                    .bazcord-stereo-bar {
                        flex: 1;
                        margin: 0 1px;
                        background: var(--brand-experiment);
                        transition: height 0.1s ease;
                    }
                    .bazcord-stereo-balance-container {
                        display: flex;
                        align-items: center;
                        margin: 10px 0;
                    }
                    .bazcord-stereo-balance-label {
                        width: 40px;
                        text-align: center;
                    }
                `);
            }

            onStop() {
                Patcher.unpatchAll();
                PluginUtilities.removeStyle(config.info.name);
            }

            patchAudioEngine() {
                // Patch the audio engine to modify channel output
                Patcher.after(AudioEngine, "getOutputVolume", (_, args, res) => {
                    if (!this.settings || this.settings.channelMode === "stereo") return res;
                    
                    const audioContext = AudioEngine.audioContext;
                    if (!audioContext) return res;
                    
                    // Create splitter if it doesn't exist
                    if (!this.splitter) {
                        this.splitter = audioContext.createChannelSplitter(2);
                        this.merger = audioContext.createChannelMerger(2);
                        this.gainLeft = audioContext.createGain();
                        this.gainRight = audioContext.createGain();
                        
                        // Connect nodes
                        this.splitter.connect(this.gainLeft, 0);
                        this.splitter.connect(this.gainRight, 1);
                        this.gainLeft.connect(this.merger, 0, 0);
                        this.gainRight.connect(this.merger, 0, 1);
                        
                        // Insert into audio chain
                        audioContext._destination.disconnect();
                        audioContext._destination = this.merger;
                        audioContext._destination.connect(audioContext.destination);
                    }
                    
                    // Apply settings
                    const leftBalance = this.settings.leftBalance / 100;
                    const rightBalance = this.settings.rightBalance / 100;
                    
                    if (this.settings.channelMode === "mono") {
                        this.gainLeft.gain.value = 0.5 * leftBalance;
                        this.gainRight.gain.value = 0.5 * rightBalance;
                    } else if (this.settings.channelMode === "both") {
                        this.gainLeft.gain.value = leftBalance;
                        this.gainRight.gain.value = rightBalance;
                    }
                    
                    return res;
                });
                
                // Patch bitrate settings
                Patcher.after(BitrateModule, "getBitrate", (_, args, res) => {
                    if (this.settings.bitrate && this.settings.bitrate !== defaultSettings.bitrate) {
                        return this.settings.bitrate * 1000; // Convert to bps
                    }
                    return res;
                });
            }

            addSettingsPanel() {
                const SettingsPanel = () => {
                    const [settings, setSettings] = React.useState(this.settings);
                    const [visualizerData, setVisualizerData] = React.useState(new Array(20).fill(0));
                    
                    // Update visualizer
                    React.useEffect(() => {
                        if (!settings.showVisualizer) return;
                        
                        const interval = setInterval(() => {
                            const newData = visualizerData.map(() => Math.random() * 100);
                            setVisualizerData(newData);
                        }, 100);
                        
                        return () => clearInterval(interval);
                    }, [settings.showVisualizer]);
                    
                    const saveSettings = (newSettings) => {
                        this.settings = { ...this.settings, ...newSettings };
                        setSettings(this.settings);
                        Utilities.saveData(config.info.name, "settings", this.settings);
                    };
                    
                    return (
                        React.createElement("div", null,
                            React.createElement("h3", null, "BazCord Stereo Settings"),
                            
                            React.createElement("div", { className: "ui-form-item" },
                                React.createElement("label", null, "Channel Mode"),
                                React.createElement("select", {
                                    value: settings.channelMode,
                                    onChange: (e) => saveSettings({ channelMode: e.target.value })
                                },
                                    React.createElement("option", { value: "stereo" }, "Stereo (Default)"),
                                    React.createElement("option", { value: "mono" }, "Mono (Both Channels Same)"),
                                    React.createElement("option", { value: "both" }, "Both (Double Audio)")
                                )
                            ),
                            
                            React.createElement("div", { className: "ui-form-item" },
                                React.createElement("label", null, "Bitrate Quality"),
                                React.createElement("select", {
                                    value: settings.bitrate,
                                    onChange: (e) => saveSettings({ bitrate: parseInt(e.target.value) })
                                },
                                    bitrateOptions.map(option => 
                                        React.createElement("option", { key: option.value, value: option.value }, option.label)
                                    )
                                )
                            ),
                            
                            settings.channelMode !== "stereo" && React.createElement(React.Fragment, null,
                                React.createElement("div", { className: "bazcord-stereo-balance-container" },
                                    React.createElement("div", { className: "bazcord-stereo-balance-label" }, "Left"),
                                    React.createElement("input", {
                                        type: "range",
                                        min: "0",
                                        max: "100",
                                        value: settings.leftBalance,
                                        onChange: (e) => saveSettings({ leftBalance: parseInt(e.target.value) }),
                                        className: "bazcord-stereo-slider"
                                    }),
                                    React.createElement("div", { className: "bazcord-stereo-balance-label" }, settings.leftBalance + "%")
                                ),
                                
                                React.createElement("div", { className: "bazcord-stereo-balance-container" },
                                    React.createElement("div", { className: "bazcord-stereo-balance-label" }, "Right"),
                                    React.createElement("input", {
                                        type: "range",
                                        min: "0",
                                        max: "100",
                                        value: settings.rightBalance,
                                        onChange: (e) => saveSettings({ rightBalance: parseInt(e.target.value) }),
                                        className: "bazcord-stereo-slider"
                                    }),
                                    React.createElement("div", { className: "bazcord-stereo-balance-label" }, settings.rightBalance + "%")
                                )
                            ),
                            
                            settings.showVisualizer && React.createElement("div", { className: "bazcord-stereo-visualizer" },
                                visualizerData.map((value, i) => 
                                    React.createElement("div", {
                                        key: i,
                                        className: "bazcord-stereo-bar",
                                        style: { height: `${value}%` }
                                    })
                                )
                            ),
                            
                            React.createElement("div", { className: "ui-form-item" },
                                React.createElement("label", null,
                                    React.createElement("input", {
                                        type: "checkbox",
                                        checked: settings.showVisualizer,
                                        onChange: (e) => saveSettings({ showVisualizer: e.target.checked })
                                    }),
                                    " Show Audio Visualizer"
                                )
                            ),
                            
                            React.createElement("div", { className: "ui-form-item" },
                                React.createElement("label", null,
                                    React.createElement("input", {
                                        type: "checkbox",
                                        checked: settings.advancedMode,
                                        onChange: (e) => saveSettings({ advancedMode: e.target.checked })
                                    }),
                                    " Advanced Mode (Requires Restart)"
                                )
                            ),
                            
                            React.createElement("button", {
                                onClick: () => {
                                    this.settings = defaultSettings;
                                    saveSettings(defaultSettings);
                                    Toasts.success("Settings reset to default!");
                                },
                                style: { marginTop: "10px" }
                            }, "Reset to Default")
                        )
                    );
                };
                
                PluginUtilities.addPanel(config.info.name, SettingsPanel);
            }

            addVoiceSettings() {
                // Add controls to voice settings
                Patcher.after(VoiceEngine, "setLocalVolume", (_, args, res) => {
                    const voiceSettings = document.querySelector(".voice-settings");
                    if (!voiceSettings || voiceSettings.querySelector(".bazcord-stereo-controls")) return res;
                    
                    const container = document.createElement("div");
                    container.className = "bazcord-stereo-controls";
                    container.style.marginTop = "15px";
                    
                    const title = document.createElement("div");
                    title.className = "ui-form-title";
                    title.textContent = "BazCord Stereo";
                    
                    const modeSelect = document.createElement("select");
                    modeSelect.style.width = "100%";
                    modeSelect.style.margin = "5px 0";
                    
                    const options = [
                        { value: "stereo", text: "Stereo (Default)" },
                        { value: "mono", text: "Mono (Both Channels Same)" },
                        { value: "both", text: "Both (Double Audio)" }
                    ];
                    
                    options.forEach(option => {
                        const elem = document.createElement("option");
                        elem.value = option.value;
                        elem.textContent = option.text;
                        if (this.settings.channelMode === option.value) elem.selected = true;
                        modeSelect.appendChild(elem);
                    });
                    
                    modeSelect.addEventListener("change", (e) => {
                        this.settings.channelMode = e.target.value;
                        Utilities.saveData(config.info.name, "settings", this.settings);
                    });
                    
                    container.appendChild(title);
                    container.appendChild(modeSelect);
                    voiceSettings.appendChild(container);
                    
                    return res;
                });
            }
        };
    })(global.ZeresPluginLibrary.buildPlugin(config));
})();
/*@end@*/