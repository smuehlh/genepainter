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

$(function () {

    $.ajaxSetup ({
     cache: false
    });

    // set up uploaders
    set_up_fileupload("#sequence_uploader");
    set_up_fileupload("#gene_structures_uploader");
    set_up_fileupload("#species_mapping_uploader");

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
            alert('File must be less than 50 MB. <br /> Please contact us to upload larger files.');
          }
      },
      submit: function() {
          hide_show_waiting('show');
      }
  });
}

function hide_show_waiting(kind) {

    if (kind === 'show') {

        $('#waiting').css({'height' : $(document).height()});
        $('#waiting').show();
    }
    else {
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
    map = JSON.parse(str_map.replace(/&quot;/g, '"').replace(/=&gt;/g, ':'));

  $.each(speciesCells, function() {
    this.innerText = map[$(this).attr('data')];
  });
}
