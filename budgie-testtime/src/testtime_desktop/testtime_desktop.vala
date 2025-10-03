using Gtk;
using Math;
using Cairo;
using Wnck;
using GLib;


/*
* BudgieTestTimeII
* Author: Jacob Vlijm
* Copyright © 2017 Ubuntu Budgie Developers
* Website=https://ubuntubudgie.org
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or any later version.
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details. You should have received a copy of the GNU General Public
* License along with this program.  If not, see
* <https://www.gnu.org/licenses/>.
*/

/*
Note:
if testtime window exists on primary -> don't recreate on primary, but make
it move to the right position (set_position()) from within the window.
so:
- no action from applet
- move window from itself
*/


namespace  TestTime {

    private string fontcolor;
    private int linespacing;
    private Label testlabel;
    private Label timelabel;
    private Label seriallabel;
    GLib.Settings testtime_settings;
    bool subwindow;
    string win_name;
    int[] custom_posargs;

    private class TestTimeappearance {

        public void get_appearance (Gdk.Screen screen) {
            // get font properties: color
            fontcolor = testtime_settings.get_string("fontcolor");
            // get font properties: font & size
            string testprops = testtime_settings.get_string("testfont");
            string timeprops = testtime_settings.get_string("timefont");
            string dateprops = testtime_settings.get_string("serialfont");
            // set fonts
            var testfont = new Pango.FontDescription().from_string(testprops);
            var timefont = new Pango.FontDescription().from_string(timeprops);
            var serialfont = new Pango.FontDescription().from_string(dateprops);
            Pango.Context tt = testlabel.get_pango_context();
            Pango.Context t = timelabel.get_pango_context();
            Pango.Context d = seriallabel.get_pango_context();
            tt.set_font_description(testfont);
            t.set_font_description(timefont);
            d.set_font_description(serialfont);
            testlabel.set_margin_end (10);
            timelabel.set_margin_end (10);
            get_spacing(screen);
        }

        public void get_spacing (Gdk.Screen screen) {
            string linespacing_css = """
            .linespacing {
              margin-bottom: <bspac>px;
            }
            """.replace( "<bspac>", linespacing.to_string());
            // set / update time label
            Gtk.CssProvider css_provider = new Gtk.CssProvider();
            testlabel.get_style_context().remove_class("linespacing");
            timelabel.get_style_context().remove_class("linespacing");
            try {
                css_provider.load_from_data(linespacing_css);
                Gtk.StyleContext.add_provider_for_screen(
                    screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
                );
                testlabel.get_style_context().add_class("linespacing");
                timelabel.get_style_context().add_class("linespacing");
            }
            catch (Error e) {
                // not much to be done
                print("Error loading css data\n");
            }
        }

        public void get_hexcolor(
            string currtest, string currtime, string currdate
        ) {
            testlabel.set_markup (
                "<span foreground=\"" +
                fontcolor + "\">" + currtest +
                "</span>"
            );
            timelabel.set_markup (
                "<span foreground=\"" +
                fontcolor + "\">" + currtime +
                "</span>"
            );
            seriallabel.set_markup (
                "<span foreground=\"" +
                fontcolor + "\">" + currdate +
                "</span>"
            );
        }
    }

    public class TimeWindow : Gtk.Window {

        GLib.Settings? panel_settings;
        GLib.Settings? currpanelsubject_settings;
        bool testtime_onpanel = true;
        int next_time;
        string dateformat;
        TestTimeappearance appearance;
        bool bypass;
        GLib.Settings text_scaling;
        bool close_onnew;
        string serial;
        string test_chamber;


        private bool find_applet (string uuid, string[] applets) {
            for (int i = 0; i < applets.length; i++) {
                if (applets[i] == uuid) {
                    return true;
                }
            }
            return false;
        }

        void watchapplet (string uuid) {
            // make loop end if applet is removed
            string general_path = "com.solus-project.budgie-panel";
            string[] applets;
            panel_settings = new GLib.Settings(general_path);
            string[] allpanels_list = panel_settings.get_strv("panels");
            foreach (string p in allpanels_list) {
                string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
                currpanelsubject_settings = new GLib.Settings.with_path(
                    general_path + ".panel", panelpath
                );

                applets = currpanelsubject_settings.get_strv("applets");
                if (find_applet(uuid, applets)) {
                    currpanelsubject_settings.changed["applets"].connect(() => {
                        applets = currpanelsubject_settings.get_strv("applets");
                        if (!find_applet(uuid, applets)) {
                            testtime_onpanel = false;
                            this.destroy();
                        }
                    });
                    break;
                }
            }
        }

        public TimeWindow (string uuid) {
            test_chamber = "Test Chamber #" + "%03d".printf(GLib.Random.int_range(1, 501));
            serial = "SERIAL NO " + uuid;
            GLib.Timeout.add_seconds(1, ()=> {
                watchapplet(uuid);
                return false;
            });
            close_onnew = false;
            // define stuff
            bypass = false;
            // on allmonitors settings change, kill window
            testtime_settings = new GLib.Settings(
                "org.ubuntubudgie.plugins.budgie-testtime"
            );
            testtime_settings.changed["allmonitors"].connect(kill_onallmonitorschange);
            // same on resolution/connect monitor change; easier to recreate than move
            screen = this.get_screen();
            screen.monitors_changed.connect(() => {
                consider_toleave();
            });
            // ...and quit on creation of similarly named window
            unowned Wnck.Screen scr = Wnck.Screen.get_default();
            scr.window_opened.connect(watchwins);
            // ok, finally we can start off with the real work
            dateformat = get_dateformat();
            appearance = new TestTimeappearance();
            // window
            this.title = win_name;
            this.set_type_hint(Gdk.WindowTypeHint.DESKTOP);
            this.resizable = false;
            this.destroy.connect(Gtk.main_quit);
            this.set_decorated(false);
            var maingrid = new Grid();
            testlabel = new Label("");
            timelabel = new Label("");
            seriallabel = new Label("");
            // position
            maingrid.attach(testlabel, 0, 0, 10, 1);
            maingrid.attach(timelabel, 0, 1, 10, 1);
            maingrid.attach(seriallabel, 0, 2, 10, 1);
            // images
            Gtk.Image[] images = new Gtk.Image[10];
            for (int i=0; i < 10; i++) {
                var original_pixbuf = new Gdk.Pixbuf.from_file("/usr/share/pixmaps/portal/" + "%02d".printf(i+1) + "_portal_on.png");
                var scaled_pixbuf = original_pixbuf.scale_simple(48, 48, InterpType.BILINEAR);
                images[i] = new Gtk.Image.from_pixbuf(scaled_pixbuf);
                maingrid.attach(images[i], i, 3, 1, 1);
            }

            this.add(maingrid);
            string[] bind = {
                "leftalign", "xposition",
                "yposition", "linespacing", "fontcolor", "linespacing",
                "testfont", "timefont", "serialfont"
            };
            foreach (string s in bind) {
                testtime_settings.changed[s].connect(update_appearance);
            }
            testtime_settings.changed["draggable"].connect(toggle_draggable);
            update_appearance();
            appearance.get_appearance(screen);
            // transparency
            this.set_app_paintable(true);
            var visual = screen.get_rgba_visual();
            this.set_visual(visual);
            this.draw.connect(on_draw);
            this.show_all();
            set_windowposition();
            this.configure_event.connect(setcondition);
            testtime_settings.changed["autoposition"].connect(set_windowposition);
            new Thread<bool> ("oldtimer", run_time);
            text_scaling = new GLib.Settings(
                "org.gnome.desktop.interface"
            );
            string[] restart_keys = {
                "text-scaling-factor", "font-name"
            };
            foreach (string s in restart_keys) {
                text_scaling.changed[s].connect_after(update_appearance_delay);
            };
        }

        private void consider_toleave() {
            if (subwindow) {
                Gtk.main_quit();
            }
            else {
                set_windowposition();
            }
        }

        private void kill_onallmonitorschange () {
            if (subwindow) {
                consider_toleave();
            }
        }

        private void watchwins (Wnck.Window newwin) {;
            // watch new windows, self-sacrifice if a new one appears
            if (newwin.get_name() == win_name) {
                // surpass killing on self-generated signal...
                if (close_onnew) {
                    consider_toleave();
                }
                close_onnew = true;
            }
        }

        private bool setcondition () {
            // act on window event
            bypass = !bypass;
            // -but not if the window is draggable...
            bool drag = testtime_settings.get_boolean("draggable");
            if (!bypass && !drag) {
                set_windowposition();
            }
            return false;
        }

        private bool get_leftalign () {
            return testtime_settings.get_boolean("leftalign");
        }

        private int[] get_windowsize () {
            int width;
            int height;
            this.get_size (out width, out height);
            return {width, height};
        }

        public int getscale () {
            var prim = Gdk.Display.get_default().get_primary_monitor();
            int scaling = prim.get_scale_factor();
            return scaling;
        }

        public void set_windowposition () {
            int scale = getscale();
            int setx;
            int sety;
            string anchor;
            // if position arguments were given, surpass calculating
            if (subwindow) {
                setx = custom_posargs[0];
                sety = custom_posargs[1];
                anchor = "se";
            }
            else if (testtime_settings.get_boolean("autoposition")) {
                int[] newpos = get_default_right();
                setx = newpos[0];
                sety = newpos[1];
                anchor = "se";
            }
            else {
                /* N.B.
                Gdk detects incorrect resolution when scaling is other than 100%.
                This leads to errors -unless- the window moves itself, directly
                counting with the incorrect resolution. move() makes the exact
                same mistake, which then eliminates the first.
                When windowposition is set from real position though (gsettings)
                we need to compensate, by multiplying by 1/scale.
                */
                anchor = testtime_settings.get_string("anchor");
                setx = testtime_settings.get_int("xposition") / scale;
                sety = testtime_settings.get_int("yposition") / scale;
            }
            int[] winsize = get_windowsize();
            int usedx = setx;
            int usedy = sety;
            if (anchor.contains("e")) {
                usedx = setx - winsize[0];
            }
            if (anchor.contains("s")) {
                usedy = sety - winsize[1];
            }
            this.move(usedx, usedy);
        }

        private int[] get_default_right () {
            int[] screendata = check_res();
            int x = screendata[0] + screendata[2] - 150;
            int y = screendata[1] + screendata[3] - 150;
            return {x, y};
        }

        private int[] check_res() {
            // see what is the resolution on the primary monitor
            var prim = Gdk.Display.get_default().get_primary_monitor();
            var geo = prim.get_geometry();
            int width = geo.width;
            int height = geo.height;
            int screen_xpos = geo.x;
            int screen_ypos = geo.y;
            return {width, height, screen_xpos, screen_ypos};
        }

        private bool on_draw (Widget da, Context ctx) {
            // needs to be connected to transparency settings change
            ctx.set_source_rgba(0, 0, 0, 0);
            ctx.set_operator(Cairo.Operator.SOURCE);
            ctx.paint();
            ctx.set_operator(Cairo.Operator.OVER);
            return false;
        }

        private int get_containingindex (string[] arr, string lookfor) {
            // get index of string in list
            for (int i=0; i < arr.length; i++) {
                if(lookfor.contains(arr[i])) return i;
            }
            return -1;
        }

        private string fix_mins(int minutes) {
            // make sure the minutes are displayed in double digits
            string minsdisplay = minutes.to_string();
            if (minsdisplay.length == 1) {
                return "0".concat(minsdisplay);
            }
            return minsdisplay;
        }

        private string get_localtime (DateTime newtime) {
            int mins = newtime.get_minute();
            int hrs = newtime.get_hour();
            int newhrs = hrs;
            string prefix = "Testing initiated ";
            string suffix = " Hours ";
            string ending = " Minutes ago";
            string showmins = fix_mins(mins);
            // hrs to double digits
            string hrs_display = fix_mins(newhrs);
            return @"$prefix$hrs_display$suffix$showmins$ending";
        }

        private string get_dateformat () {
            string date_fmt = testtime_settings.get_string("dateformat");
            if (date_fmt == "") {return read_dateformat();}
            return date_fmt;
        }

        private string read_dateformat () {
            string[] monthvars = {
                "%B", "%-b", "%_b", "%h", "%-h", "%_h", "%b"
            };
            string[] daynamevars = {
                "%A", "%a", "%-a", "%-A", "%_a", "%_A"
            };
            string[] monthdayvars = {
                "%e", "%-e", "%_e", "%d", "%-d", "%_d"
            };
            string cmd = Config.PACKAGE_BINDIR + "/locale date_fmt";
            string output = "";
            try {
                StringBuilder builder = new StringBuilder ();
                GLib.Process.spawn_command_line_sync(cmd, out output);
                string[] output_data = output.split(" ");
                foreach (string s in output_data) {
                    // make it a function? nah, we're lazy
                    if (get_containingindex(monthvars, s) != -1) {
                        builder.append (monthvars[0]).append (" ");
                    }
                    else if (get_containingindex(daynamevars, s) != -1) {
                        builder.append (daynamevars[0]).append (" ");
                    }
                    else if (get_containingindex(monthdayvars, s) != -1) {
                        builder.append (monthdayvars[0]).append (" ");
                    }
                }
                return builder.str;
            }
            catch (Error e) {
                return "";
            }
        }

        private void toggle_draggable () {
            bool draggable = testtime_settings.get_boolean("draggable");
            if (draggable) {
                this.set_type_hint(Gdk.WindowTypeHint.NORMAL);
            }
            else {
                this.set_type_hint(Gdk.WindowTypeHint.DESKTOP);
            }
        }

        private void update_appearance_delay() {
            GLib.Timeout.add( 50, () => {
                update_appearance();
                return false;
            } );
        }
        private void update_appearance () {
            // text align
            int al = 1;
            if (get_leftalign()) {al = 0;}
            testlabel.xalign = al;
            timelabel.xalign = al;
            seriallabel.xalign = al;
            // showdate
            linespacing = testtime_settings.get_int("linespacing");
            appearance.get_appearance(screen);
            update_interface();
        }

        private void update_interface () {
            var now = new DateTime.now_local();
            // string datestring = now.format(dateformat);
            appearance.get_hexcolor(test_chamber, get_localtime(now), serial);
        }

        private int convert_remainder_topositive (double subj, double rem) {
            // Math.remainder possibly gives a negative output, seems silly
            if (rem < 0) {return (int)(subj + rem);}
            return (int)rem;
        }

        private int[] calibrate_time () {
            /*
            the cycle is double-layered: once per 6 seconds, there is a
            dconf check to see if the applet is still on the panel
            (kill the thread & window if not), once per minute fine-
            tune the minute-sync. On startup, we need to synchroonize
            the cycle so that time update is done exactly on minute-
            switch. additionally, once per minute we sync with real clock
             */
            var curr_time = new DateTime.now_local();
            int curr_sec = curr_time.get_second();
            int curr_remaining = convert_remainder_topositive(
                6, Math.remainder (60 - (double)curr_sec, 6)
            );
            int remaining_cycles = (int)((60 - curr_sec) / 6);
            return {curr_remaining, remaining_cycles};
        }

        private bool run_time () {
            // make sure time shows instantly
            update_interface();
            calibrate_time();
            // this is the main time-loop
            int[] calibrated_loopdata = calibrate_time();
            int loopcycle = 0;
            while (testtime_onpanel) {
                if (loopcycle == 0){
                    next_time = calibrated_loopdata[0];
                }
                if (loopcycle >= calibrated_loopdata[1]) {
                    calibrated_loopdata = calibrate_time();
                    loopcycle = 0;
                    Idle.add ( () => {
                        update_interface();
                        return false;
                    });
                }
                loopcycle += 1;
                Thread.usleep(next_time * 1000000);
                next_time = 6;
            }
            return false;
        }
    }

    public static void main (string[] args) {
        /* 0 = application, 1=uuid, 2=monitor, 3=x, 4=y */
        string uuid = args[1];
        Gtk.init(ref args);
        win_name = "Testtime";
        if (args.length == 5) {
            subwindow = true;
            win_name = "Testtime_".concat(args[2]);
            custom_posargs = {int.parse(args[3]), int.parse(args[4])};
        }
        new TimeWindow(uuid);
        Gtk.main();
    }
}