// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require jquery-fileupload/basic
//= require underscore
//= require turbolinks
//= require view_helpers
//= require_tree .

$( window ).bind('beforeunload', function() {
  $.ajax({
    type: 'POST',
    url: '/clean_up'
  });
});

$(function () {

    $.ajaxSetup ({
     cache: false
    });

    // set up uploaders
    set_up_fileupload("#sequence_uploader");
    set_up_fileupload("#gene_structures_uploader");
    set_up_fileupload("#species_mapping_uploader");
    set_up_fileupload("#pdb_uploader");

    create_alignment_file_ajax();
});

function set_up_fileupload(btnSelector) {
  $(btnSelector).fileupload({
      autoUpload: false,
      add: function(e, data) {
          if (data.files[0].size <= 52428800) {
            data.submit();
          } else {
            // TODO: nicer error modal
            error('File must be less than 50 MB. <br /> Please contact us to upload larger files.');
          }
      },
      submit: function() {
          hide_show_waiting('show');
      }
  });
}

function hide_show_waiting(kind) {

    if (kind === 'show') {
        var sec = 0;
        function pad(val) { return val > 9 ? val : "0" + val; }
        myInterval = setInterval(function () {
            $("#seconds").html(pad(++sec % 60));
            $("#minutes").html(pad(parseInt(sec / 60, 10) % 60));
            $("#hours").html(pad(parseInt(sec / 3600, 10)));
        }, 1000);

        $('#waiting').css({'height' : $(document).height()});
        $('#waiting').show();
    }
    else {
        clearInterval(myInterval);
        $('#waiting').hide();
    }
};

function create_alignment_file_ajax() {
  $('textarea#text_seq').first().on('input', function() {
    if (this.value.length) {
      var that = this;

      $.ajax({
        type: 'POST',
        url: '/create_alignment_file',
        data: {'sequence': that.value},
        dataType: 'script'
      });
    }
  });
}

function update_data_center_table(str_map) {
  var speciesCells = $('td#species'),
    map = JSON.parse(str_map.replace(/&quot;/g, '"').replace(/""/g, '"').replace(/=&gt;/g, ':'));

  $.each(speciesCells, function() {
    this.innerText = map[$(this).attr('data')];
  });
}

/*
 * .addClassSVG(className)
 * Adds the specified class(es) to each of the set of matched SVG elements.
 */
$.fn.addClassSVG = function(className){
    $(this).attr('class', function(index, existingClassNames) {
        return existingClassNames + ' ' + className;
    });
    return this;
};

/*
 * .removeClassSVG(className)
 * Removes the specified class to each of the set of matched SVG elements.
 */
$.fn.removeClassSVG = function(className){
    $(this).attr('class', function(index, existingClassNames) {
        var re = new RegExp(className, 'g');
        return existingClassNames.replace(re, '');
    });
    return this;
};

$.fn.sc_ExecuteAjaxQ = function (options) {
  //? Executes a series of AJAX methods in dequence

  var options = $.extend({

      fx: [] //function1 () { }, function2 () { }, function3 () { }

  }, options);

  if (options.fx.length > 0) {

      var i = 0;

      $(this).unbind('ajaxComplete');
      $(this).ajaxComplete(function () {

          i++;
          if (i < options.fx.length && (typeof options.fx[i] == "function")) { options.fx[i](); }
          else { $(this).unbind('ajaxComplete'); }

      });

      //Execute first item in queue
      if (typeof options.fx[i] == "function") { options.fx[i](); }
      else { $(this).unbind('ajaxComplete'); }
  }
}
