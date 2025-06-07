--- Skyfarm Shared Config
--- Created by judea.
--- DateTime: 7/06/2025 4:41 pm
---

-- CONFIG
return {

    -- IDS
    ids = {
        drill = 0,
        deployer = 20,
        pusher = 5,
        drawer_sky = 23,
        monitor = 24,
        server = 28,
        lv1 = 6,
        lv2 = 26,
        lv3 = 25,
        lv4 = 27,
        lv5 = 12,
        lv6 = 7,
        lv7 = 13,
        lv8 = 8,
        lv9 = 14,
        lv10 = 9,
        lv11 = 15,
        lv12 = 10,
        lv13 = 16,
        lv14 = 11,
        lv15 = 17,
    },

    names = {
        [0] = "drill",
        [5] = "pusher",
        [6] = "lv1",
        [7] = "lv6",
        [8] = "lv8",
        [9] = "lv10",
        [10] = "lv12",
        [11] = "lv14",
        [12] = "lv5",
        [13] = "lv7",
        [14] = "lv9",
        [15] = "lv11",
        [16] = "lv13",
        [17] = "lv15",
        [20] = "deployer",
        [23] = "drawer_sky",
        [24] = "monitor",
        [25] = "lv3",
        [26] = "lv2",
        [27] = "lv4",
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

      deploy = "deploy",
      deploy_done = "RD",

      drill_frontward = "frontward",
      drill_backward = "backward",
      drill_full_front = "DFF",
      drill_full_back = "DFB",

      plate_moved = "LVL",
      plate_grounded = "LVL1",
      plate_top = "LVL15",

      sky_fill = "sky-fill",
    }
}