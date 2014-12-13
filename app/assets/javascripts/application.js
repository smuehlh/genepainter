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
var ajax_prefix = '';
$( document ).ready(function() {
    ajax_prefix = $("body").attr("data-ajaxprefix");
});

function build_ajax_path(url) {
  return (ajax_prefix + url).replace('//','/');
};

$( window ).bind('beforeunload', function() {
  $.ajax({
    type: 'POST',
    url: build_ajax_path('/clean_up'),
  });
});

$(function() {
  $( document ).tooltip();
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
      singleFileUploads: false,
      multipart: true,
      add: function(e, data) {
          if (data.files[0].size <= 52428800) {
            data.submit();
          } else {
            error('File must be less than 50 MB. <br /> Please contact us to upload larger files.');
          }
      },
      submit: function() {
          hide_show_waiting('show');
      }
  });
}

var sec = 0;
var myInterval = false;
function hide_show_waiting(kind) {
    if (kind === 'show') {
        $('#waiting').css({'height' : $(document).height()});
        $('#waiting').show();
        function pad(val) { return val > 9 ? val : "0" + val; }
        sec = 0;       
        $("#seconds").html(pad(0));
        $("#minutes").html(pad(0));
        $("#hours").html(pad(0));
        myInterval = setInterval(function () {
            ++sec;     
            $("#seconds").html(pad(sec % 60));
            $("#minutes").html(pad(parseInt(sec / 60, 10) % 60));
            $("#hours").html(pad(parseInt(sec / 3600, 10)));
        }, 1000);
    }
    else {
        $('#waiting').hide();
        clearInterval(myInterval);
    }
};

// dependency between analyse and generate-checkbox
function update_datacenter_checkboxes(analyse_checkbox_elem) {
  var myId, myGene;
  myId = analyse_checkbox_elem.id;
  myGene = myId.replace('_analyse', '');

  if (analyse_checkbox_elem.checked) {
    // checked 

    // status of corresponding gene structure; empty if no gene structure present
    var myStat = $("#"+myGene+"_status").html(); 
    // corresponding species; empty if no species mapped
    var mySpec = $("#"+myGene+"_species").html();
    
    // show generate checkbox if no genestructure present and species is known!
    if (myStat === "" && mySpec !== "") {
      $("#" + myGene + "_generate").show();
    }    
  } else {
    // not checked

    // hide generate gene struct-checkbox and un-check it
    $("#" + myGene + "_generate").prop('checked', false);
    $("#" + myGene + "_generate").hide();
  }
}

function create_alignment_file_ajax() {
  $('textarea#text_seq').first().on('blur', function() {
    if (this.value.length) {
      var that = this;

      $.ajax({
        type: 'POST',
        url: build_ajax_path('/create_alignment_file'),
        data: {'sequence': that.value},
        dataType: 'script'
      });
    }
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
