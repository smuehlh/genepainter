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
var maxAllowedAnalyse = 50;
var maxAllowedGenerate = 5;

function build_ajax_path(url) {
  return (ajax_prefix + url).replace('//','/');
};

$( window ).bind('beforeunload', function() {
  $.ajax({
    type: 'POST',
    url: build_ajax_path('/clean_up'),
    data: {'authenticity_token': authenticity_token}
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

            // validate max number of files
            if (data.files.length > maxAllowedAnalyse ) {
              all_valid = false;
              error("Upload maximum "+ maxAllowedAnalyse + " files!");
              return false;
            }

            // validate each file
            var all_valid = true;
            for (var i = 0; i < data.files.length; i++) {
                var file = data.files[i];
                all_valid = validate_file(file, btnSelector); // renders error if file is not valid!  
                if (! all_valid) {
                    return false;
                }    
            }
            if (all_valid) {
                data.submit();
            }
      },
      submit: function() {
          hide_show_waiting('show');
      }
  });
}
function validate_file(file, selector) {
    var is_valid = true;

    // check file type
    var accepted_types = $(selector).attr("accept");
    var file_type = file.name.split(".").pop();  
    if (accepted_types.indexOf(file_type) == -1) {      
        is_valid = false;
        error("File(s) must be of type " + accepted_types );
    }

    // check file size
    if (file.size > 52428800) {
        is_valid = false;
        error("File(s) must be less than 50 MB. <br /> Please contact us to upload larger files. <br /> Offending file: " + file.name);
    }
    return is_valid;
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

// restricts number of checked checkboxes in _datacenter_ 
function restrict_num_checked_checkboxes(checkboxEle, maxAllowed, name, warningItem) {
    // limit number of checked checkboxes
    var nChecked = $("#dataCenterForm input[type=checkbox][name='" + name + "[]']:checked").length;   
    if ( nChecked > maxAllowed ) {
      $(checkboxEle).prop('checked', false);
      warning( warningItem );
    }
}

// call on onclick-event of analyse checkbox
function update_datacenter(analyse_checkbox_elem) {
  update_datacenter_checkboxes(analyse_checkbox_elem); 
  update_datacenter_buttons();
}

// dependency between analyse-checkboxes and buttons
// if analyse-checkboxes visible: enable select-all/deselect-all buttons
// if analyse-checkboxes checked: enable submit button
function update_datacenter_buttons() {
  nChecked = $(".analyse_checkbox:checked").length;
  nVisible = $(".analyse_checkbox:visible").length;
  if (nChecked > 0) {
    $("#data_center_button").prop("disabled", false);
    $("#data_center_info").hide();
  } else {
    $("#data_center_button").prop("disabled", true);
    $("#data_center_info").show("slow");  
  }
  if (nVisible > 0) {
    $("#toggle_analyse_none").prop("disabled", false);
    $("#toggle_analyse_all").prop("disabled", false);
  } else {
    $("#toggle_analyse_none").prop("disabled", true);
    $("#toggle_analyse_all").prop("disabled", true);
  };
}

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
    var mySpec = $("#"+myGene+"_hidden").val();   
    
    // show generate checkbox if no genestructure present and species is known!
    if (myStat === "" && mySpec !== "") {
      $("#" + myGene + "_generate").show();
    }    
  } else {
    // not checked

    // un-check generate gene struct-checkbox
    $("#" + myGene + "_generate").prop('checked', false);
    // $("#" + myGene + "_generate").hide();
  }
}

function create_alignment_file_ajax() {
  $('textarea#text_seq').first().on('blur', function() {
    if (this.value.length) {
      var that = this;
      var authenticity_token = $('meta[name=csrf-token]').attr('content');
      $.ajax({
        type: 'POST',
        url: build_ajax_path('/create_alignment_file'),
        data: {'sequence': that.value, "authenticity_token": authenticity_token},
        dataType: 'script'
      });
    }
  });
}
