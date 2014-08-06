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
