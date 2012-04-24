// usage: log('inside coolFunc', this, arguments);
// paulirish.com/2009/log-a-lightweight-wrapper-for-consolelog/
window.log = function(){
  log.history = log.history || [];   // store logs to an array for reference
  log.history.push(arguments);
  if(this.console) console.log( Array.prototype.slice.call(arguments) );
};

// catch all document.write() calls
(function(doc){
  var write = doc.write;
  doc.write = function(q){
    log('document.write(): ',arguments);
    if (/docwriteregexwhitelist/.test(q)) write.apply(doc,arguments); 
  };
})(document);

$(document).ready(function() {
	$('#notify-close').click(function() {
		$('#ie-warning').slideUp();
	});
	$("#notify-close a").click(function() {
		$('#ie-warning').slideUp();
		return false;
	});
});

// place any jQuery/helper plugins in here, instead of separate, slower script files.