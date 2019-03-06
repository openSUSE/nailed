function bugzilla(colors, product, bugzilla_url){
  // BugZilla
  product_ = product.replace(/_/g, " ");
  $.getJSON("/json/bugzilla/" + product + "/trend/open", function (json) {
    new Morris.Line({
      element: 'bug_trend',
      data: json,
      xkey: 'time',
      ykeys: ['open', 'fixed'],
      yLabelFormat: function(y){return y != Math.round(y)?'':y;},
      labels: ['Open', 'Fixed'],
      resize: true,
      fillOpacity: 0.5,
      smooth: false,
      hideHover: true,
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
        window.open(bugzilla_url+"&query_format=advanced&resolution=---");
    });
  });
  $.getJSON("/json/bugzilla/" + product + "/bar/priority", function (json) {
    new Morris.Bar({
      element: 'bug_prio',
      data: json,
      xkey: 'bugprio',
      ykeys: ['p0', 'p1', 'p2', 'p3', 'p4', 'p5'],
      labels: ['P0 - Crit Sit', 'P1 - Urgent', 'P2 - High', 'P3 - Medium', 'P4 - Low', 'P5 - None'],
      resize: true,
      stacked: true,
      hideHover: true,
      barColors: [ colors["bar"]["black"],
                   colors["bar"]["red"],
                   colors["bar"]["orange"],
                   colors["bar"]["yellow"],
                   colors["bar"]["green"],
                   colors["bar"]["blue"]
                 ],
      hoverCallback: function (index, options, content, row) {
        var ret = '';
        if (typeof row.p0 !== "undefined")
          return row.p0;
        else if (typeof row.p1 !== "undefined")
          return row.p1;
        else if (typeof row.p2 !== "undefined")
          return row.p2;
        else if (typeof row.p3 !== "undefined")
          return row.p3;
        else if (typeof row.p4 !== "undefined")
          return row.p4;
        else if (typeof row.p5 !== "undefined")
          return row.p5;
      }
    }).on('click', function(i, row){
      if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
        jQuery.noop();
      else
        window.open(bugzilla_url+"&order=Importance&priority="+row.bugprio+"&query_format=advanced&resolution=---");
    });
  });
  $.getJSON("/json/bugzilla/" + product + "/bar/status", function (json) {
    new Morris.Bar({
      element: 'bug_status',
      data: json,
      xkey: 'bugstatus',
      ykeys: ['s0', 's1', 's2', 's3'],
      labels: ['NEW', 'CONFIRMED', 'IN_PROGRESS', 'REOPENED'],
      xLabelMargin: 11,
      resize: true,
      stacked: true,
      hideHover: true,
      barColors: [ colors["bar"]["black"],
                   colors["bar"]["red"],
                   colors["bar"]["orange"],
                   colors["bar"]["yellow"]
                 ],
      hoverCallback: function (index, options, content, row) {
        var ret = '';
        if (typeof row.s0 !== "undefined")
          return row.s0;
        else if (typeof row.s1 !== "undefined")
          return row.s1;
        else if (typeof row.s2 !== "undefined")
          return row.s2;
        else if (typeof row.s3 !== "undefined")
          return row.s3;
      }
    }).on('click', function(i, row){
      if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
        jQuery.noop();
      else
        window.open(bugzilla_url+"&bug_status="+row.bugstatus+"&query_format=advanced&resolution=---");
    });
  });
  $.getJSON("/json/bugzilla/" + product + "/donut/component", function (json) {
    new Morris.Donut({
      element: 'top_components',
      data: json,
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
        window.open(bugzilla_url+"&order=Importance&component="+row.label+"&query_format=advanced&resolution=---");
    });
  });
}
