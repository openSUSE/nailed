/* Formatters */
function bugzillaPriority(priority) {
  if (priority == "P1 - Urgent") {
    return '<span class="label label-danger">' + priority + '</span>' ;
  } else if (priority == "P0 - Crit Sit") {
    return '<span class="label label-default">' + priority + '</span>';
  } else if (priority == "P2 - High") {
    return '<span class="label label-warning">' + priority + '</span>' ;
  } else if (priority == "P3 - Medium") {
    return '<span class="label label-yellow">' + priority + '</span>' ;
  } else if (priority == "P4 - Low") {
    return '<span class="label label-success">' + priority + '</span>' ;
  } else if (priority == "P5 - None") {
    return '<span class="label label-info">' + priority + '</span>' ;
  }
}

function timestampReduce(timestamp) {
  arr = timestamp.split("T");
  return arr[0];
}

function bugzillaFromLink(url, row) {
  return '<a class="btn btn-default btn-sm" href="' + url + '" target="_blank">' + row.bug_id + '</a>';
}

function githubFromLink(url, row) {
  return '<a class="btn btn-default btn-sm" href="' + url + '" target="_blank">' + row.pr_number + '</a>';
}

function routeUrl(url) {
  return '<a href="' + url + '" target="_blank">' + url + '</a>';
}
