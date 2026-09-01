const Applet = imports.ui.applet;
const Cinnamon = imports.gi.Cinnamon;
const Clutter = imports.gi.Clutter;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;

class StatusMenuItem extends PopupMenu.PopupBaseMenuItem {
    constructor(proxy) {
        super();
        this.proxy = proxy;
        this.box = new St.BoxLayout({ style_class: "red-status-overflow-item" });
        this.icon = new St.Icon({ icon_size: 20 });
        this.label = new St.Label({ y_align: Clutter.ActorAlign.CENTER });
        this.box.add_child(this.icon);
        this.box.add_child(this.label);
        this.addActor(this.box);
        this._changedId = proxy.connect("g-properties-changed", () => this.refresh());
        this.refresh();
        this.connect("activate", () => this.activateStatusIcon());
    }

    refresh() {
        const iconName = this.proxy.icon_name || "application-x-executable-symbolic";
        if (iconName.includes("/"))
            this.icon.gicon = Gio.icon_new_for_string(iconName);
        else
            this.icon.icon_name = iconName;
        this.label.text = this.proxy.tooltip_text || this.proxy.name.replace("org.x.StatusIcon.", "");
    }

    activateStatusIcon() {
        const allocation = Cinnamon.util_get_transformed_allocation(this.actor);
        const x = Math.round(allocation.x1 / global.ui_scale);
        const y = Math.round(allocation.y2 / global.ui_scale);
        const now = global.get_current_time();
        this.proxy.call_button_press(x, y, 1, now, Gtk.PositionType.TOP, null, null);
        this.proxy.call_button_release(x, y, 1, now, Gtk.PositionType.TOP, null, null);
    }

    destroy() {
        if (this._changedId) {
            this.proxy.disconnect(this._changedId);
            this._changedId = 0;
        }
        super.destroy();
    }
}

class RedStatusOverflowApplet extends Applet.IconApplet {
    constructor(metadata, orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);
        this.set_applet_icon_symbolic_name("pan-up-symbolic");
        this.set_applet_tooltip("Background apps");
        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);
        this.proxies = {};
        this.monitor = new imports.gi.XApp.StatusIconMonitor();
        this._addedId = this.monitor.connect("icon-added", (_monitor, proxy) => this.addProxy(proxy));
        this._removedId = this.monitor.connect("icon-removed", (_monitor, proxy) => this.removeProxy(proxy));
    }

    key(proxy) {
        return proxy.get_name() + proxy.get_object_path();
    }

    addProxy(proxy) {
        this.proxies[this.key(proxy)] = proxy;
        this.updateTooltip();
    }

    removeProxy(proxy) {
        delete this.proxies[this.key(proxy)];
        this.updateTooltip();
    }

    updateTooltip() {
        const count = Object.values(this.proxies).filter(proxy => this.isBackgroundApp(proxy)).length;
        this.set_applet_tooltip(count ? `Background apps (${count})` : "Background apps");
    }

    isBackgroundApp(proxy) {
        // Core system indicators belong permanently on the panel.  Only
        // actual applications belong in this compact overflow menu.
        const identity = `${proxy.name || ""} ${proxy.tooltip_text || ""}`.toLowerCase();
        return !/(bluetooth|update|upgrade|network|wifi|wireless|battery|power|volume|audio|microphone)/.test(identity);
    }

    on_applet_clicked() {
        this.menu.removeAll();
        const entries = Object.values(this.proxies)
            .filter(proxy => proxy.visible && this.isBackgroundApp(proxy))
            .sort((a, b) => a.name.localeCompare(b.name));
        if (!entries.length) {
            const empty = new PopupMenu.PopupMenuItem("No background apps", { reactive: false });
            empty.actor.add_style_class_name("red-status-overflow-empty");
            this.menu.addMenuItem(empty);
        } else {
            const heading = new PopupMenu.PopupMenuItem("BACKGROUND APPS", { reactive: false });
            heading.actor.add_style_class_name("red-status-overflow-heading");
            this.menu.addMenuItem(heading);
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            for (const proxy of entries)
                this.menu.addMenuItem(new StatusMenuItem(proxy));
        }
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        if (this._addedId) this.monitor.disconnect(this._addedId);
        if (this._removedId) this.monitor.disconnect(this._removedId);
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new RedStatusOverflowApplet(metadata, orientation, panelHeight, instanceId);
}
