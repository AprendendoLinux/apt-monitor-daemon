"""Gera HTML de exemplo de todos os e-mails (data fixa, para capturas comparáveis): gen.py PASTA_DE_SAIDA"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src"))
import apt_monitor as am  # noqa: E402

out = sys.argv[1]
now = 1795000000
U, P, R, PP = am.Update, am.PackageResult, am.RunRecord, am.PendingPackage
tz = "America/Sao_Paulo"
upd = [U("linux-image-amd64", "6.1.76-1", "6.1.85-1", True), U("openssl", "3.0.11-1", "3.0.13-1", True),
       U("libssl3", "3.0.11-1", "3.0.13-1", True), U("curl", "7.88.1-10", "7.88.1-11", False),
       U("nginx", "1.22.0-1", "1.22.1-1", False), U("tzdata", "2024a-0", "2024b-0", False)]
runs = [R(1, now - 9 * 3600, None, 12, 0, [P("openssl:amd64", "3.0.11-1", "3.0.13-1", True),
                                            P("curl:amd64", "7.88.1-10", "7.88.1-11", True),
                                            P("linux-image-amd64:amd64", "6.1.76-1", "6.1.85-1", True)]),
        R(2, now - 2 * 3600, None, 3, 1, [P("nginx:amd64", "1.22.0-1", "1.22.1-1", False),
                                           P("tzdata:all", "2024a-0", "2024b-0", True),
                                           P("vim:amd64", "9.0.1-1", "9.0.2-1", True)])]
pend = [PP("openssl", "3.0.11-1", "3.0.13-1", True, now - 6 * 86400), PP("libssl3", "3.0.11-1", "3.0.13-1", True, now - 6 * 86400),
        PP("linux-image-amd64", "6.1.76-1", "6.1.85-1", True, now - 5 * 86400), PP("curl", "7.88.1-10", "7.88.1-11", False, now - 4 * 86400),
        PP("vim", "9.0.1-1", "9.0.2-1", False, now - 86400)]
host, ips, day = "srv-prod", "192.168.1.50", "2026-11-24"
pages = {
    "admin-critico": am.Alert("new", host, ips + ", 2001:db8::50", upd, True, ["linux-image-6.1.76"], now, tz).email_html(),
    "admin-comum": am.Alert("new", host, ips, upd[3:5], False, [], now, tz).email_html(),
    "admin-lembrete": am.Alert("reminder", host, ips, upd[1:3], False, [], now, tz).email_html(),
    "admin-em-dia": am.Alert("cleared", host, ips, [], False, [], now, tz).email_html(),
    "cliente": am.DailyReport(host, ips, day, runs, "Henrique Fagundes", tz, pending=4, reboot=True, now=now).email_html(),
    "cliente-vazio": am.DailyReport(host, ips, day, [], "", tz, now=now).email_html(),
    "cliente-pendencias": am.DailyReport(host, ips, day, [], "Henrique Fagundes", tz, overdue=pend, overdue_days=3, now=now).email_html(),
    "cliente-misto": am.DailyReport(host, ips, day, runs, "Henrique Fagundes", tz, overdue=pend, overdue_days=3, now=now).email_html(),
}
for name, page in pages.items():
    with open(os.path.join(out, name + ".html"), "w", encoding="utf-8") as handle:
        handle.write(page)
print(" ".join(sorted(pages)))
