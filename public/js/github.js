function github(colors, org, repo){
  // GitHub
  $.getJSON("/json/github/" + repo + "/trend/open", function (json) {
    new Morris.Line({
      element: 'pull_trend',
      data: json,
      xkey: 'time',
      ykeys: ['open'],
      yLabelFormat: function(y){return y != Math.round(y)?'':y;},
      labels: ['Open'],
      resize: true,
      hideHover: true,
      smooth: false,
      continuousLine: true,
      lineColors: [ colors["line"]["red"],
                    colors["line"]["green"]
                  ],
      hoverCallback: function (index, options, content, row) {
        return content;
      }
    }).on('click', function(i, row){
      if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
        jQuery.noop();
      else
        window.open("https://github.com/" + org + "/" + repo + "/pulls");
    });
  });
}
