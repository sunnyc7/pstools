'use strict';

/*
 * .scriptload InvertedFunctionTable.js
 * dx -g @$InvertedFunctionTable("Ps") ; KeUser set by default
 * [...] ; <- it's clickable in WinDbg
 * dx -c 100 -g @$InvertedFunctionTable("Ps")
 * [...]
 * and so on
 *
 * Getting the same result with manual input:
 * dx @$table = *(nt!_INVERTED_FUNCTION_TABLE **)&nt!KeUserInvertedFunctionTable
 * dx -g @$table->TableEntry->Take(@$table->CurrentSize)
 * ; for PsInvertedFunctionTable
 * dx -g ((nt!_INVERTED_FUNCTION_TABLE *)&nt!PsInvertedFunctionTable)->TableEntry->Take(0xBE)
 */
function *InvertedFunctionTable(prefix = 'KeUser') {
  if (!host.currentSession.Attributes.Target.IsKernelTarget) {
    host.diagnostics.debugLog('Incorrect debugger environment.\n');
  }

  let table = host.createPointerObject(
    host.getModuleSymbolAddress('nt', (prefix + 'InvertedFunctionTable')),
    'nt', `_INVERTED_FUNCTION_TABLE ${'Ps' === prefix ? '*' : '**'}`
  );

  if ('KeUser' === prefix) table = table.dereference();
  for (let entry of table.TableEntry.Take('KeUser' === prefix ? table.CurrentSize : 0xBE)) yield entry;
}

function initializeScript() {
  return [new host.functionAlias(InvertedFunctionTable, 'InvertedFunctionTable')];
}
