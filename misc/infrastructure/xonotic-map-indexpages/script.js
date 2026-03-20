// We have js so rename the Date column to Age to suit relative times
document.getElementById("dateheader").textContent = "Age";

var timeunit_name = [ " min", " hour", " day", " week", " month", " year", ];
var timeunit_secs = [ 60,     3600,    86400,  604800,  2629746,  31556952 ]; // month: 365.2425*86400/12

var tsformatter = new Intl.DateTimeFormat('default', {year:'numeric', month: 'numeric', day: 'numeric', hour:'numeric', minute:'numeric', hour12: false, timeZoneName: 'short'});

function aging()
{
	var refresh_int = 86400; // setTimeout limit is 2147483647 ms
	var now_ut = Math.round(new Date().getTime() / 1000);

	for (var elem of document.getElementsByTagName("time"))
	{
		var ut = parseFloat(elem.getAttribute("data-ut"));
		var age = now_ut - ut;

		for (var i = 0; i < timeunit_secs.length - 1; ++i)
			if (age < timeunit_secs[i+1])
				break;

		var age_str;
		if (i > 0)
		{
			var age_major = Math.floor(age / timeunit_secs[i]);
			var age_minor = age - (timeunit_secs[i] * age_major);
			age_minor = Math.round(age_minor / timeunit_secs[i-1]);
			if (age_minor * timeunit_secs[i-1] == timeunit_secs[i])
			{
				++age_major;
				age_minor = 0;
			}
			age_str = age_major + timeunit_name[i] + (age_major == 1 ? "" : "s");
			if (age_major < 12 && age_minor > 0)
				age_str += ", " + age_minor + timeunit_name[i-1] + (age_minor == 1 ? "" : "s");
		}
		else
			age_str = Math.round(age / timeunit_secs[i]) + timeunit_name[i] + (age == 1 ? "" : "s");

		if (elem.textContent != age_str)
			elem.textContent = age_str;

		// Set the timestamp as the mouseover text
		if (!elem.title)
			elem.title = tsformatter.format(new Date(ut * 1000));

		// Refresh ages often enough for +/- 5% accuracy of the smallest unit
		var r = timeunit_secs[i > 0 ? i-1 : i] * 0.05;
		if (r < refresh_int)
			refresh_int = r;
	}

	window.setTimeout(aging, refresh_int * 1000);
}
aging();
