--- Skyfarm Shared Config
--- Created by judea.
--- DateTime: 7/06/2025 4:41 pm
---

-- CONFIG
return {

    -- IDS
    ids = {
        drill = 0,
        dff = 2,
        dfb = 3,
        deployer = 20,
        pusher = 5,
        drawer_sky = 23,
        monitor = 24,
        server = 28,
        LV1 = 6,
        LV2 = 26,
        LV3 = 25,
        LV4 = 27,
        LV5 = 12,
        LV6 = 7,
        LV7 = 13,
        LV8 = 8,
        LV9 = 14,
        LV10 = 9,
        LV11 = 15,
        LV12 = 10,
        LV13 = 16,
        LV14 = 11,
        LV15 = 17,
    },

    names = {
        [0] = "drill",
        [2] = "dff",
        [3] = "dfb",
        [5] = "pusher",
        [6] = "LV1",
        [7] = "LV6",
        [8] = "LV8",
        [9] = "LV10",
        [10] = "LV12",
        [11] = "LV14",
        [12] = "LV5",
        [13] = "LV7",
        [14] = "LV9",
        [15] = "LV11",
        [16] = "LV13",
        [17] = "LV15",
        [20] = "deployer",
        [23] = "drawer_sky",
        [24] = "monitor",
        [25] = "LV3",
        [26] = "LV2",
        [27] = "LV4",
        [28] = "server"
    },

    protocols = {
        control = "sky-control",
        reply = "sky-reply",
        logs = "sky-logs",
        status = "sky-status",
        fill = "sky-fill",
        share = "sky-share"
    },


    thresholds = {
        sky_stop = 90,
        sky_resume = 10
    },



    keywords = {
      update = "update",
      ping = "ping",
      pong = "pong",

      deploy = "deploy",
      deploy_done = "RD",

      drill_frontward = "frontward",
      drill_backward = "backward",
      drill_full_front = "DFF",
      drill_full_back = "DFB",

      plate_moved = "LVL",
      plate_grounded = "LVL1",
      plate_top = "LVL15",

      fill = "sky-fill",
    }
}