// assets/js/app.js

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let togglePlayLocked = false;

let Hooks = {
  PlingButton: {
    mounted() {
      this.el.addEventListener("pointerdown", (e) => {
        const button = e.currentTarget.querySelector("button");
        if (!button.disabled) {
          this.handlePointerDown();
        }
      });
    },

    handlePointerDown() {
      console.log("click");
      if (togglePlayLocked) {
        setTimeout(() => {
          this.pushEvent("toggle_play");
          window.EmbedController?.togglePlay();
          const wrapper = document.querySelector(".embed-wrapper");
          if (wrapper) {
            wrapper.classList.toggle("hidden");
          }
        }, 200);
      } else {
        this.pushEvent("toggle_play");
        window.EmbedController?.togglePlay();
        const wrapper = document.querySelector(".embed-wrapper");
        if (wrapper) {
          wrapper.classList.toggle("hidden");
        }
      }
    },
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0,0,0,.3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

window.onSpotifyIframeApiReady = (IFrameAPI) => {
  console.log("Spotify IFrame API ready");
  const element = document.getElementById("embed-iframe");
  if (!element) {
    console.warn("Spotify embed iframe not found");
    return;
  }

  const initialTrack = element.getAttribute("data-initial-track");
  const callback = (EmbedController) => {
    console.log("Spotify Embed Controller initialized");
    window.EmbedController = EmbedController;
  };

  let options = {
    uri: initialTrack || "spotify:track:3SFXsFpeGmBTtQvKiwYMDA",
    theme: "dark",
  };

  setTimeout(() => {
    console.log("Creating Spotify controller with options:", options);
    IFrameAPI.createController(element, options, callback);
  }, 0);
};

window.addEventListener("phx:spotify:load_track", (event) => {
  console.log("Loading track:", event.detail.track);
  const track = event.detail.track;
  window.EmbedController?.loadUri(track.uri);

  togglePlayLocked = true;
  setTimeout(() => {
    togglePlayLocked = false;
  }, 200);
});

window.addEventListener("phx:ring_bell", (event) => {
  console.log("Playing bell sound");
  const startTime = event.detail.start_time;
  const now = Date.now();

  const bell = document.getElementById("bell");
  bell?.play();
});

window.addEventListener("popstate", (_event) => {
  console.log("Browser back detected - pausing player");
  window.EmbedController?.pause();
});

window.addEventListener("phx:spotify:toggle_play", (_event) => {
  // window.EmbedController?.togglePlay();
  const wrapper = document.querySelector(".embed-wrapper");
  if (wrapper) {
    wrapper.classList.toggle("hidden");
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect();

window.liveSocket = liveSocket;
