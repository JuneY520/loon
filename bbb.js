[Script]
http-response ^https?:\/\/appi\.lanerc\.net\/app\/rank requires-body=1 max-size=0,script-path=https://example.com/empty-rank.js,tag=屏蔽广告-APP-RANK

[MITM]
hostname = appi.lanerc.net

// empty-rank.js
var body = JSON.stringify({
  code: 200,
  message: "Success",
  data: []
});
$done({ body });