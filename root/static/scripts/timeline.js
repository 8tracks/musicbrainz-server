setup_graphing = {};
$(document).ready(function () {
    var category_id_prefix = 'category-';
    var control_id_prefix = 'graph-control-';

    var datasets = {};
    var graph_options = {};
    var overview_options = {};

    function graph_data () {
        var alldata =  [];
        $("#graph-lines div input").filter(":checked").each(function () { 
            if ($(this).parents('div.graph-category').prev('.toggler').children('input:checkbox').attr('checked')) {
                alldata.push(datasets[$(this).parent('div.graph-control').attr('id').substr(control_id_prefix.length)]);
            }
        });
        return alldata
    }

    function jq(myid) { 
        return '#' + myid.replace(/(:|\.)/g,'\\$1');
    }

    // Make selections zoom
    $('#graph-container').bind('plotselected', function (event, ranges) {
        // clamp the zooming to prevent eternal zoom
        if (ranges.xaxis.to - ranges.xaxis.from < 86400000)
        ranges.xaxis.to = ranges.xaxis.from + 86400000;
    if (ranges.yaxis.to - ranges.yaxis.from < 1)
        ranges.yaxis.to = ranges.yaxis.from + 1;

    // do the zooming
    plot = $.plot($("#graph-container"), graph_data(), 
        $.extend(true, {}, graph_options, {
            xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
        yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
        }));
    });
    $('#overview').bind('plotselected', function(event, ranges) {
        plot.setSelection(ranges);
    });

    // "Reset Graph" functionality
    $('#graph-container, #overview').bind('plotunselected', function () { resetPlot(); });

    // Hover functionality
    function showTooltip(x, y, contents) {
        $('<div id="tooltip">' + contents + '</div>').css( {
            position: 'absolute',
            display: 'none',
            top: y + 5,
            left: x + 5,
            border: '1px solid #fdd',
            padding: '2px',
            'background-color': '#fee',
            opacity: 0.80
        }).appendTo("body").fadeIn(200);
    }
    previousPoint = null;
    $('#graph-container').bind('plothover', function (event, pos, item) { 
        if(item) {
            if (previousPoint != item.dataIndex) {
                previousPoint = item.dataIndex;

                $("#tooltip").remove();
                var x = item.datapoint[0],
        y = item.datapoint[1],
        date = new Date(parseInt(x));

    if (date.getDate() < 10) { day = '0' + date.getDate(); } else { day = date.getDate(); }
    if (date.getMonth()+1 < 10) { month = '0' + (date.getMonth()+1); } else { month = date.getMonth()+1; }

    showTooltip(item.pageX, item.pageY,
        date.getFullYear() + '-' + month + '-' + day + ": " + y + " " + item.series.label);
            }
        } else {
            $('#tooltip').remove();
            previousPoint = null;
        }
    });

    function change_hash(minus, new_hash_part, hide) {
        if (hide != minus) {
            if (location.hash.indexOf(new_hash_part) == -1) {
                window.location.hash = location.hash + (location.hash != '' ? '+' : '') + (minus ? '-' : '') + new_hash_part;
            } else {
                window.location.hash = location.hash.replace(new RegExp('-?' + new_hash_part), (minus ? '-' : '') + new_hash_part);
            }
        } else {
            remove_from_hash('-?' + new_hash_part);
        }
    }

    function remove_from_hash(to_remove) {
        window.location.hash = location.hash.replace(new RegExp('\\+?' + to_remove), '');
    }

    function check(name, toggle, categoryp) {
        if (categoryp) {
            var $checkbox_parent = $(jq(category_id_prefix + name)).prev('.toggler');
        } else {
            var $checkbox_parent = $(jq(control_id_prefix + 'count.' + name));
        }
        $checkbox_parent.children('input:checkbox').attr('checked', toggle).change();
    }

    $(window).hashchange(function () {
        var hash = location.hash.replace( /^#/, '' );
        var queries = hash.split('+');

        $.each(queries, function (index, value) {
            var remove = (value.substr(0,1) == '-');
            if (remove) {
                value = value.substr(1);
            }
            var category = (value.substr(0,2) == 'c-');
            if (category) {
                value = value.substr(2);
            }
            check(value, !remove, category);
        });
    });


    function resetPlot () {
        plot = $.plot($("#graph-container"), graph_data(), graph_options);
        overview = $.plot($('#overview'), graph_data(), overview_options);
    }

    setup_graphing = function (data, goptions, ooptions) {
        datasets = data;
	graph_options = goptions;
	overview_options = ooptions;

        $.each(datasets, function(key, value) { 
            if ($(jq(control_id_prefix + key)).length == 0) {
                if ($('#' + category_id_prefix + value.category).length == 0) {
                    $('#graph-lines').append('<h2 class="toggler"><input type="checkbox" checked />' + MB.text.Timeline.Category[value.category].Label + '</h2>');
                    $('#graph-lines').append('<div class="graph-category" id="category-' + value.category + '"></div>');
                }
                $("#graph-lines #category-" + value.category).append('<div class="graph-control" id="' + control_id_prefix + key + '"><input type="checkbox" checked />' + value.label + '</div>'); 
            }
        });
        // // Toggle functionality
        $('#graph-lines div input:checkbox').change(function () {
            var minus = !$(this).attr('checked');
            var new_hash_part = $(this).parent('div').attr('id').substr((control_id_prefix + 'count.').length);
            var hide = (MB.text.Timeline[$(this).parent('div').attr('id').substr(control_id_prefix.length)].Hide ? true : false);
            change_hash(minus, new_hash_part, hide);

            resetPlot();
        });
        $('#graph-lines .toggler input:checkbox').change(function () {
            var $this = $(this);

            var category_id = $this.parent('.toggler').next('div.graph-category').attr('id');
            var minus = !$this.attr('checked');
            var new_hash_part = category_id.replace(/category-/, 'c-');
            var hide = (MB.text.Timeline.Category[category_id.substr(category_id_prefix.length)].Hide ? true : false);
            change_hash(minus, new_hash_part, hide);
    
            $this.parent('.toggler').next()[minus ? 'hide' : 'show']('slow');
            resetPlot();
        });


        $('div.graph-category').each(function () {
            var category = $(this).attr('id').substr(category_id_prefix.length);
            if (MB.text.Timeline.Category[category].Hide) {
                $(this).prev('.toggler').children('input:checkbox').attr('checked', false).change();
            }
        });

        $('div.graph-control').each(function () {
            var identifier = $(this).attr('id').substr(control_id_prefix.length);
            if (MB.text.Timeline[identifier].Hide) {
                $(this).children('input:checkbox').attr('checked', false).change();
            }
        });


        $(window).hashchange();
        resetPlot();
    }


});
