function index(pulltop, bugtop, l3trend, product_query, colors){
  new Morris.Donut({
    element: 'pull_top',
    data: pulltop,
    colors: [ colors["pie"]["red"],
              colors["pie"]["orange"],
              colors["pie"]["yellow"],
              colors["pie"]["green"],
              colors["pie"]["blue"]
            ],
    resize: true,
    formatter: function(y, data){
      return y;
    }
  }).on('click', function(i, row){
    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
      jQuery.noop();
    else
      window.open("/github/"+row.label,"_self");
  });
  new Morris.Donut({
    element: 'bug_top',
    data: bugtop,
    colors: [ colors["pie"]["red"],
              colors["pie"]["orange"],
              colors["pie"]["yellow"],
              colors["pie"]["green"],
              colors["pie"]["blue"]
            ],
    resize: true
  }).on('click', function(i, row){
    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
      jQuery.noop();
    else
      window.open("/"+row.label.replace(/ /g,'_')+"/bugzilla","_self");
  });
  new Morris.Line({
    element: 'l3_trend',
    data: l3trend,
    xkey: 'time',
    ykeys: ['open'],
    yLabelFormat: function(y){return y != Math.round(y)?'':y;},
    labels: ['Open'],
    resize: true,
    hideHover: true,
    lineColors: [ colors["line"]["red"],
                  colors["line"]["green"]
                ],
    smooth: false,
    continuousLine: true,
    hoverCallback: function (index, options, content, row) {
      return content;
    }
  }).on('click', function(i, row){
    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
      jQuery.noop();
    else
      window.open("https://bugzilla.suse.com/buglist.cgi?product="+product_query+"&status_whiteboard=openL3&status_whiteboard_type=allwordssubstr&query_format=advanced&resolution=---");
  });
}
