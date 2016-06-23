$(document).ready(function () {
  $('#dashboard-table.table').DataTable({
    scrollY: '60vh',
    scrollX: true,
    scrollCollapse: true,
    fixedColumns: true,
    searching: false,
    ordering: false,
    paging: false,
    info: false
  });
});
