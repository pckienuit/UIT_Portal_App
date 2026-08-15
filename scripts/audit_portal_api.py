from __future__ import annotations

import argparse
import html
import json
import re
import ssl
import sys
from dataclasses import dataclass
from http.cookiejar import CookieJar
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.parse import urlencode, urljoin, urlparse
from urllib.request import HTTPCookieProcessor, HTTPRedirectHandler, Request, build_opener

PORTAL = "https://portal.uit.edu.vn"
LOGIN = f"{PORTAL}/api/auth/login"
# Only verified, non-mutating contracts. Do not probe retired, unknown, or
# state-changing endpoints here: this audit runs against a real student account.
ENDPOINTS = [
    ("GET", "/api/sinh-vien/tkb?hocKy=1&namHoc=2025&yearId=2025", None),
    ("POST", "/api/sinh-vien/lich-thi", {"hocKy": 1, "namHoc": 2025, "yearId": 2025}),
    ("GET", "/api/sinh-vien/lich-sinh-hoat?hocKy=1&namHoc=2025&yearId=2025", None),
    ("POST", "/api/sinh-vien/khao-sat-giang-day", {}),
    ("GET", "/api/sinh-vien/giay-xac-nhan", None),
    ("GET", "/api/sinh-vien/xac-nhan-chung-chi", None),
    ("GET", "/api/sinh-vien/bang-diem", None),
    ("GET", "/api/sinh-vien/diem-ren-luyen", None),
    ("GET", "/api/sinh-vien/xin-bang-diem", None),
    ("GET", "/api/sinh-vien/hoan-thi", None),
    ("GET", "/api/sinh-vien/phuc-khao", None),
    ("GET", "/api/sinh-vien/the-sinh-vien", None),
    ("GET", "/api/sinh-vien/gui-xe", None),
    ("GET", "/api/sinh-vien/khoa-luan", None),
    ("GET", "/api/sinh-vien/tot-nghiep", None),
    ("GET", "/api/sinh-vien/hoc-bong", None),
    ("GET", "/api/sinh-vien/ho-tro", None),
    ("GET", "/api/sinh-vien/bao-hiem", None),
    ("GET", "/api/sinh-vien/gia-han-hoc-phi", None),
    ("GET", "/api/sinh-vien/thoi-hoc-bao-luu", None),
    ("POST", "/api/sv/tuition", {
        "tuition_field_list": ["id", "semester", "year_id", "tuition_amount", "remaining"],
        "detail_field_list": ["id", "subject_code", "subject_name", "amount"],
    }),
    ("GET", "/api/public/announcements", None),
]
ROUTES = [
    "/",
    "/sinh-vien/tkb",
    "/sinh-vien/ho-so",
    "/sinh-vien/bang-diem",
    "/sinh-vien/diem-ren-luyen",
    "/sinh-vien/xin-bang-diem",
    "/sinh-vien/hoan-thi",
    "/sinh-vien/phuc-khao",
    "/sinh-vien/giay-xac-nhan",
    "/sinh-vien/xac-nhan-chung-chi",
    "/sinh-vien/the-sinh-vien",
    "/sinh-vien/gui-xe",
    "/sinh-vien/khoa-luan",
    "/sinh-vien/tot-nghiep",
    "/sinh-vien/hoc-bong",
    "/sinh-vien/ho-tro",
    "/sinh-vien/lich-sinh-hoat",
    "/sinh-vien/bao-hiem",
    "/sinh-vien/hoc-phi",
    "/sinh-vien/gia-han-hoc-phi",
    "/sinh-vien/thoi-hoc-bao-luu",
    "/sinh-vien/lich-thi",
    "/sinh-vien/khao-sat-giang-day",
]


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


@dataclass
class Response:
    status: int
    url: str
    headers: Any
    body: bytes


class PortalSession:
    def __init__(self) -> None:
        self.cookies = CookieJar()
        context = ssl.create_default_context()
        self.opener = build_opener(HTTPCookieProcessor(self.cookies))
        self.no_redirect = build_opener(HTTPCookieProcessor(self.cookies), NoRedirect())
        self.context = context

    def request(
        self,
        url: str,
        *,
        method: str = "GET",
        data: bytes | None = None,
        headers: dict[str, str] | None = None,
        redirects: bool = True,
    ) -> Response:
        req = Request(url, data=data, headers=headers or {}, method=method)
        opener = self.opener if redirects else self.no_redirect
        try:
            with opener.open(req, timeout=30) as res:
                return Response(res.status, res.url, res.headers, res.read())
        except HTTPError as error:
            return Response(error.code, error.url, error.headers, error.read())

    def login(self, username: str, password: str) -> None:
        initial = self.request(LOGIN, redirects=False)
        auth_url = initial.headers.get("Location")
        if not auth_url:
            raise RuntimeError(f"Portal login did not redirect: HTTP {initial.status}")

        login_page = self.request(auth_url)
        text = login_page.body.decode("utf-8", "replace")
        match = re.search(r'id="kc-form-login"[^>]*action="([^"]+)"', text)
        if not match:
            match = re.search(r'<form[^>]*action="([^"]+)"', text)
        if not match:
            raise RuntimeError("UIT SSO login form not found")

        action = html.unescape(match.group(1))
        form = urlencode(
            {"username": username, "password": password, "credentialId": ""}
        ).encode()
        submitted = self.request(
            action,
            method="POST",
            data=form,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            redirects=False,
        )
        callback = submitted.headers.get("Location")
        if submitted.status == 200 or not callback:
            raise RuntimeError("UIT SSO rejected credentials or requested extra verification")
        if "code=" not in callback:
            raise RuntimeError(f"UIT SSO returned unexpected redirect: {urlparse(callback).path}")

        completed = self.request(callback, redirects=False)
        while completed.status in {301, 302, 303, 307, 308}:
            location = completed.headers.get("Location")
            if not location:
                break
            completed = self.request(urljoin(completed.url, location), redirects=False)

        check = self.request(PORTAL, redirects=False)
        location = check.headers.get("Location", "")
        if check.status in {301, 302, 303, 307, 308} and (
            "sso.uit.edu.vn" in location or "/api/auth/login" in location
        ):
            raise RuntimeError("Portal session was not established")


def schema(value: Any) -> Any:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "double"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return [] if not value else [schema(value[0])]
    if isinstance(value, dict):
        return {key: schema(item) for key, item in value.items()}
    return type(value).__name__


def summarize(response: Response) -> dict[str, Any]:
    content_type = response.headers.get("Content-Type", "")
    result: dict[str, Any] = {
        "status": response.status,
        "content_type": content_type.split(";", 1)[0],
        "bytes": len(response.body),
    }
    location = response.headers.get("Location")
    if location:
        result["location_host"] = urlparse(location).hostname
        result["location_path"] = urlparse(location).path
    if "json" in content_type:
        try:
            result["schema"] = schema(json.loads(response.body))
        except json.JSONDecodeError:
            result["invalid_json"] = True
    elif response.body:
        text = response.body.decode("utf-8", "replace")
        result["title"] = next(
            iter(re.findall(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)), None
        )
    return result


def discover_paths(session: PortalSession, route_results: dict[str, Any]) -> list[str]:
    scripts: set[str] = set()
    paths: set[str] = set()
    for route in ROUTES:
        response = session.request(f"{PORTAL}{route}", redirects=False)
        route_results[route] = summarize(response)
        if response.status != 200:
            continue
        text = response.body.decode("utf-8", "replace")
        scripts.update(
            urljoin(PORTAL, src)
            for src in re.findall(r'<script[^>]+src="([^"]+)"', text)
            if "_next/static" in src
        )
        paths.update(re.findall(r"/api/[A-Za-z0-9_?&=./{}$:-]+", text))
        paths.update(re.findall(r"/sinh-vien/[A-Za-z0-9_-]+", text))

    for script in sorted(scripts):
        response = session.request(script)
        if response.status != 200:
            continue
        text = response.body.decode("utf-8", "replace")
        paths.update(re.findall(r"/api/[A-Za-z0-9_?&=./{}$:-]+", text))
        paths.update(re.findall(r"/sinh-vien/[A-Za-z0-9_-]+", text))
    return sorted(path.rstrip("\\\"'") for path in paths)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--username", required=True)
    parser.add_argument("--password-stdin", action="store_true", required=True)
    parser.add_argument("--output", default="build/portal-api-audit.json")
    args = parser.parse_args()
    password = sys.stdin.readline().rstrip("\r\n")
    if not password:
        raise RuntimeError("Password missing on stdin")

    session = PortalSession()
    session.login(args.username, password)

    endpoint_results: dict[str, Any] = {}
    for method, path, body in ENDPOINTS:
        encoded = json.dumps(body).encode() if body is not None else None
        headers = {"Content-Type": "application/json"} if body is not None else {}
        response = session.request(
            f"{PORTAL}{path}",
            method=method,
            data=encoded,
            headers=headers,
            redirects=False,
        )
        endpoint_results[f"{method} {path}"] = summarize(response)

    route_results: dict[str, Any] = {}
    discovered = discover_paths(session, route_results)
    report = {
        "authenticated": True,
        "endpoints": endpoint_results,
        "routes": route_results,
        "discovered_paths": discovered,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(output)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


def _self_check() -> None:
    assert schema({"items": [{"id": 1}], "error": None}) == {
        "items": [{"id": "int"}],
        "error": "null",
    }
    assert summarize(
        Response(
            200,
            PORTAL,
            {"Content-Type": "application/json; charset=utf-8"},
            b'{"items":[]}',
        )
    )["schema"] == {"items": []}


if __name__ == "__main__":
    _self_check()
    raise SystemExit(main())
