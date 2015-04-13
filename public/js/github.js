function github(pulltrend, github_url_all_pulls){
  var colors = ['#B39DDB','#9FA8DA','#90CAF9','#81D4FA','#80DEEA','#80CBC4','#A5D6A7','#C5E1A5','#E6EE9C','#FFF59D','#FFE082','#FFCC80','#FFAB91','#BCAAA4','#EEEEEE'].reverse();
  // GitHub
  new Morris.Line({
    element: 'pull_trend',
    data: pulltrend,
    xkey: 'time',
    ykeys: ['open'],
    yLabelFormat: function(y){return y != Math.round(y)?'':y;},
    labels: ['Open'],
    resize: true,
    hideHover: true,
    smooth: false,
    continuousLine: true,
    lineColors: ["#4CAF50"],
    hoverCallback: function (index, options, content, row) {
      return content;
    }
  }).on('click', function(i, row){
    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent))
      jQuery.noop();
    else
      window.open(github_url_all_pulls);
  });
  $("[creation_time]").each(function (index, value){
    var one_week = 604800;
    var two_weeks = 1209600;
    var one_month = 2629743;
    var now = Math.round((new Date()).getTime() / 1000);
    var then = $(this).attr("creation_time");
    var diff = now - then;
    if (diff < one_week) {
      $(value).css("color","#212121").attr('title', 'opened < one week ago');
    } else if (diff < two_weeks) {
      $(value).css("color","#E57373").attr('title', 'opened < two weeks ago');
    } else if (diff < one_month) {
      $(value).css("color","#C62828").attr('title', 'opened < one month ago');
    } else {
      $(value).css("color","#D50000").attr('title', 'opened > one month ago');
    }
  });
}
