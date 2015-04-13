function index(pulltop, bugtop, l3trend, product_query){
  var colors = ['#FFCDD2','#E1BEE7','#D1C4E9','#C5CAE9','#BBDEFB','#B3E5FC','#B2EBF2','#B2DFDB','#C8E6C9','#DCEDC8','#F0F4C3','#FFF9C4','#FFECB3','#FFE0B2','#FFCCBC','#D7CCC8','#F5F5F5','#CFD8DC','#EF9A9A','#CE93D8','#B39DDB','#9FA8DA','#90CAF9','#81D4FA','#80DEEA','#80CBC4','#A5D6A7','#C5E1A5','#E6EE9C','#FFF59D','#FFE082','#FFCC80','#FFAB91','#BCAAA4','#EEEEEE','#B0BEC5'].reverse();//sort(function() { return 0.5 - Math.random() });
  new Morris.Donut({
    element: 'pull_top',
    data: pulltop,
    colors: colors,
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
    colors: colors,
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
    lineColors: ["#4CAF50"],
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
  $("[last_change_time]").each(function (index, value){
    var one_week = 604800;
    var two_weeks = 1209600;
    var one_month = 2629743;
    var now = Math.round((new Date()).getTime() / 1000);
    var then = $(this).attr("last_change_time");
    var diff = now - then;
    if (diff < one_week) {
      $(value).css("color","#212121").attr('title', 'last change < one week');
    } else if (diff < two_weeks) {
      $(value).css("color","#E57373").attr('title', 'last change < two weeks');
    } else if (diff < one_month) {
      $(value).css("color","#C62828").attr('title', 'last change < one month');
    } else {
      $(value).css("color","#D50000").attr('title', 'last change > one month');
    }
  });
}
