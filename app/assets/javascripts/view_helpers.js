/**
 * @view_helpers.js This file contains helper
 * functions/wrappers for the views.
 */

/**
 * Disables or enables a jquery button or file input.
 * @param {object} $element A jQuery object
 * @param {boolean} trueOrFalse true means disabled,
 * and therefore false means enabled.
 */
function disable($element, trueOrFalse) {
  $element.prop('disabled', trueOrFalse);
}

/**
 * Get selected items from a list.
 * <ul>
 *   <li>[x] HmmCoro1A</li>
 *   <li></li>
 *   ...
 * </ul>
 * @param: itemList
 */
function getSelectedItems(itemList) {
  var items = []
  for (var i = 0; i < itemList.length; i++) {
    if ( $(itemList[i]).is(':checked') ) {

      items.push(itemList[i]);
    }
  }
  return items;
}

/**
 * Adds a species mapping block.
 */
function addSpeciesMappingBlock() {
  var $btn = $(this),
    $currentSpeciesMappingBlock = $btn.prev();

  $newBlock = $currentSpeciesMappingBlock.clone();
  new_seq_names = $newBlock.find('ul input');
  for (var i = 0; i < new_seq_names.length; i++) {
    if ( $(new_seq_names[i]).is(':checked') ) {
      $(new_seq_names[i]).parent().remove();
    }
  }

  new_seq_names.click(function() {
    disable($btn, false);
    if (getSelectedItems(new_seq_names).length == new_seq_names.length)  {
      disable($btn, true);
    }
  });

  $newBlock.insertAfter($currentSpeciesMappingBlock);
}

/**
 * Checks all input.
 * @param inputs an array of checkbox input elements.
 */
function checkAll(inputs, checkOrNot) {
  if (checkOrNot == true) {
    inputs.prop('checked', 'checked');
  } else {
    inputs.removeAttr('checked');
  }
}

// Helpers for Aligned Gene Structures section

/**
 * Returns true if there is an unique intron.
 */
function uniqIntron(introns) {

  return _.filter(introns, function(intron) {
    return intron.innerHTML == '|';
  }).length == 1;
}

function colorUniqIntronColumn(col, color) {
  _.each(col, function(element){
    $(element).css('background-color', color);
  });
}

function highlightUniqIntrons(styleOrNot) {
  var $textBasedTable = $('table#text_based_output');

  var numberOfGenes = $textBasedTable.find('tr').length,
    allCells = $textBasedTable.find('td').toArray(),
    charPerRow = allCells.length / numberOfGenes;

  intronsByColumn = []

  for (var i = 0; i < charPerRow; i++) {
    intronsByColumn.push(allCells.filter(function(value, index) {
      return (index - i) % charPerRow == 0;
    }));
  }

  for (var i = 1; i < charPerRow; i++) {
    if (uniqIntron(intronsByColumn[i])) {
      if (styleOrNot) {
        colorUniqIntronColumn(intronsByColumn[i], 'orange');
      } else {
        colorUniqIntronColumn(intronsByColumn[i], 'white');
      }
    }
  }
}
