/* Formatters */
function bugzillaPriority(priority) {
  if (priority == "P1 - Urgent") {
    return '<span class="mdc-bg-red-600">' + priority + '</span>' ;
  } else if (priority == "P2 - High") {
    return '<span class="mdc-bg-orange-600">' + priority + '</span>' ;
  } else if (priority == "P3 - Medium") {
    return '<span class="mdc-bg-yellow-600">' + priority + '</span>' ;
  } else if (priority == "P4 - Low") {
    return '<span class="mdc-bg-green-600">' + priority + '</span>' ;
  } else if (priority == "P5 - None") {
    return '<span class="mdc-bg-blue-600">' + priority + '</span>' ;
  }
}

function bugzillaFromLink(url) {
  arr = url.split("=");
  bugId = arr[arr.length - 1];
  return '<a href="' + url + '" target="_blank">' + bugId + '</a>';
}

function githubFromLink(url) {
  arr = url.split("/");
  pullNr = arr[arr.length - 1];
  return '<a href="' + url + '" target="_blank">' + pullNr + '</a>';
}
