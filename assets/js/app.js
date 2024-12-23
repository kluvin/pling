// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let Hooks = {
  PlingButton: {
    mounted() {
      this.el.addEventListener("pointerdown", () => {
        console.log("Sending toggle_play event to server");
        this.pushEvent("toggle_play");
        window.EmbedController.togglePlay();
      });
    },
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

window.onSpotifyIframeApiReady = (IFrameAPI) => {
  console.log("Spotify IFrame API ready");
  const element = document.getElementById("embed-iframe");
  if (!element) {
    console.warn("Spotify embed iframe not found");
    return;
  }

  // Get initial track from the data attribute
  const initialTrack = element.getAttribute("data-initial-track");

  const callback = (EmbedController) => {
    console.log("Spotify Embed Controller initialized");
    window.EmbedController = EmbedController;
    // Try to initialize playback state
    EmbedController.play().catch((e) =>
      console.log("Initial play attempt:", e)
    );
  };

  options = {
    uri: initialTrack || "spotify:track:3SFXsFpeGmBTtQvKiwYMDA", // Use initial track or fallback
    theme: "dark",
  };

  // Use setTimeout instead of requestAnimationFrame
  setTimeout(() => {
    console.log("Creating Spotify controller with options:", options);
    IFrameAPI.createController(element, options, callback);
  }, 0);
};

// Wrap controller actions in try-catch for better error handling
window.addEventListener("phx:spotify_play", async (_event) => {
  console.log("Playing Spotify");
  try {
    await window.EmbedController.play();
  } catch (e) {
    console.error("Error playing:", e);
  }
});

window.addEventListener("phx:spotify_pause", async (_event) => {
  console.log("Pausing Spotify");
  try {
    await window.EmbedController.pause();
  } catch (e) {
    console.error("Error pausing:", e);
  }
});

window.addEventListener("phx:update_track", (event) => {
  console.log("Updating track to:", event.detail.track);
  const track = event.detail.track;
  window.EmbedController.loadUri(track);
});

window.addEventListener("phx:ring_bell", (_event) => {
  console.log("Playing bell sound");
  document.getElementById("bell").play();
});

window.addEventListener("spotify-toggle", () => {
  window.EmbedController.togglePlay();
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Add these event handlers
window.addEventListener("phx:spotify_play", () => {
  document.querySelector(".embed-wrapper")?.classList.add("hidden");
});

window.addEventListener("phx:spotify_pause", () => {
  document.querySelector(".embed-wrapper")?.classList.remove("hidden");
});
