function getTextColor(themeType, priority, colors) {
  var textColor;
  if (themeType == "light") {
    textColor = colors["grey"]["old"]["text"];
  }
  if ((themeType == "light") && (priority == "P3 - Medium")) {
    textColor = colors["grey"]["young"]["text"];
  } 
  if (themeType == "dark") {
    textColor = colors["grey"]["old"]["text"];
  }
  if ((themeType == "dark") && (priority == "P3 - Medium")) {
    textColor = colors["grey"]["young"]["text"];
  }
  return textColor;
}

function bugzillaLastChangeTime(themeType, colors) {
  $("[last_change_time]").each(function (index, value){
    var priority = $(value).attr('priority');
    var two_weeks = 1209600;
    var one_month = 2629743;
    var now = Math.round((new Date()).getTime() / 1000);
    var then = $(this).attr("last_change_time");
    var diff = now - then;
    var textColor = getTextColor(themeType, priority, colors);
    var colorName;
    if (diff < two_weeks) {
      $(value).removeClass (function (index, css) {
        // match the color name
        colorName = css.match (/(^|\s)mdc-\S+/g)[0].split('-')[2];
        return (css.match (/(^|\s)mdc-\S+/g) || []).join(' ');
      });
      $(value).addClass(colors[colorName]["young"]["bg"] + " " + textColor).attr('title', $(this).attr("title") + " " + " | last change < two weeks ago");
    } else if (diff < one_month) {
      $(value).removeClass (function (index, css) {
        colorName = css.match (/(^|\s)mdc-\S+/g)[0].split('-')[2];
        return (css.match (/(^|\s)mdc-\S+/g) || []).join(' ');
      });
      $(value).addClass(colors[colorName]["adult"]["bg"] + " " + textColor).attr('title', $(this).attr("title") + " " + " | last change < one month ago");
    } else {
      $(value).removeClass (function (index, css) {
        colorName = css.match (/(^|\s)mdc-\S+/g)[0].split('-')[2];
        return (css.match (/(^|\s)mdc-\S+/g) || []).join(' ');
      });
      $(value).addClass(colors[colorName]["old"]["bg"] + " " + textColor).attr('title',  $(this).attr("title") + " " + " | last change > one month ago");
    }
  });
}

function bugzillaPriority(themeType, colors) {
  $("[priority]").each(function (index, value){
    var priority = $(value).attr('priority');
    var textColor = getTextColor(themeType, priority, colors);
    if (priority == "P1 - Urgent") {
      $(value).addClass(colors["red"]["young"]["bg"] + " " + textColor).attr('title', priority);
    } else if (priority == "P2 - High") {
      $(value).addClass(colors["orange"]["young"]["bg"] + " " + textColor).attr('title', priority);
    } else if (priority == "P3 - Medium") {
      $(value).addClass(colors["yellow"]["young"]["bg"] + " " + textColor).attr('title', priority);
    } else if (priority == "P4 - Low") {
      $(value).addClass(colors["green"]["young"]["bg"] + " " + textColor).attr('title', priority);
    } else if (priority == "P5 - None") {
      $(value).addClass(colors["blue"]["young"]["bg"] + " " + textColor).attr('title', priority);
    }
  });
}

function githubCreationTime(themeType, colors) {
  $("[creation_time]").each(function (index, value){
    var two_weeks = 1209600;
    var one_month = 2629743;
    var now = Math.round((new Date()).getTime() / 1000);
    var then = $(this).attr("creation_time");
    var diff = now - then;
    var colorName;
    var textColor = getTextColor(themeType, "none", colors);
    if (diff < two_weeks) {
      $(value).addClass(colors["red"]["young"]["bg"] + " " + textColor).attr('title', "created < two weeks ago");
    } else if (diff < one_month) {
      $(value).addClass(colors["red"]["adult"]["bg"] + " " + textColor).attr('title', "created < one month ago");
    } else {
      $(value).addClass(colors["red"]["old"]["bg"] + " " + textColor).attr('title',  "created > one month ago");
    }
  });
}
