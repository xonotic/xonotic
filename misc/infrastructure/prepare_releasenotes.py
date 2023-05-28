from enum import Enum
import logging
import requests
from typing import NamedTuple, TextIO
from datetime import datetime

# TODO: remove after testing
import os
import json
# end remove after testing


MR_TYPE = Enum("MR_TYPE", {"Feature(s)": 1,
                           "Fix(es)": 2,
                           "Refactoring": 3,
                           "NO_TYPE_GIVEN": 9999})

# for ordering
MR_SIZE = Enum("MR_SIZE", {"Enormous": 1,
                           "Large": 2,
                           "Medium": 3,
                           "Small": 4,
                           "Tiny": 5,
                           "UNKNOWN": 6})

TOPIC_PREFIX = "Topic: "
CHANGELOG_PREFIX = "RN::"
MR_TYPE_PREFIX = "MR Content: "
MR_SIZE_PREFIX = "MR Size::"

MAIN_PROJECT_ID = 73434
# 73444: mediasource
# 144002: xonotic.org
EXCLUDED_PROJECT_IDS: list[int] = [73444, 144002]
TARGET_BRANCHES = ["master", "pending-release"]

GROUP_NAME = "xonotic"
BASEURL = "https://gitlab.com/api/v4"
MAIN_PROJECT_BASEURL = BASEURL + f"/projects/{MAIN_PROJECT_ID}/repository"
GROUP_BASEURL = BASEURL + f"/groups/{GROUP_NAME}"


class MergeRequestInfo(NamedTuple):
    iid: int
    size: MR_SIZE
    author: str
    reviewers: list[str]
    short_desc: str
    web_url: str


def get_time_of_latest_release() -> str:
    response = requests.get(MAIN_PROJECT_BASEURL + "/tags")
    latest = response.json()[0]
    return latest["commit"]["created_at"]


def get_merge_requests(timestamp: str) -> list[dict]:
    if os.path.isfile("testdata.json"):
        with open("testdata.json") as f:
            return json.load(f)
    page_len = 10
    MAX_PAGES = 100
    url = GROUP_BASEURL + "/merge_requests?state=merged&updated_after=" +\
        f"{timestamp}&per_page={page_len}&page="
    current_page = 1
    data = []
    while True:
        response = requests.get(url + str(current_page))
        new_data = response.json()
        if not new_data:
            break
        data.extend(new_data)
        if len(new_data) < page_len:
            break
        if current_page == MAX_PAGES:
            break
        current_page += 1
    return data


def process_description(description: str) -> str:
    if not description:
        raise ValueError("Empty description")
    lines = description.splitlines()
    if not lines[0].strip() == "Summary for release notes:":
        raise ValueError("Unexpected description format: Summary missing")
    summary = ""
    for line in lines[1:]:
        if line.startswith("---"):
            continue
        if not line:
            break
        summary += line + " " # add space
    return summary.strip()



def process(timestamp: datetime, data: list[dict]) -> dict[MR_TYPE, dict[str, list[MergeRequestInfo]]]:
    # extract type, size and topic from labels for easier filtering/ordering
    # extract short description from description
    # extract author->name
    processed_data: dict = {mr_type: {} for mr_type in MR_TYPE}
    for item in data:
        if item["project_id"] in EXCLUDED_PROJECT_IDS:
            continue
        if item["target_branch"] not in TARGET_BRANCHES:
            continue
        # Workaround for missing merge information
        if "merged_at" not in item or not isinstance(item["merged_at"], str):
            logging.warning(f"Invalid merge information for {item['iid']} "
                            f"(project: {item['project_id']})")
            continue
        # GitLab's rest API doesn't offer a way to filter by "merged_after", so
        # check the "merge_at" field
        if datetime.fromisoformat(item["merged_at"]) < timestamp:
            continue
        mr_type = MR_TYPE.NO_TYPE_GIVEN
        size = MR_SIZE.UNKNOWN
        section = "UNKNOWN SECTION"
        for label in item["labels"]:
            if label.startswith(MR_TYPE_PREFIX):
                try:
                    new_mr_type = MR_TYPE[label.removeprefix(MR_TYPE_PREFIX)]
                except KeyError:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_mr_type.value < mr_type.value:
                    mr_type = new_mr_type
                continue
            if label.startswith(MR_SIZE_PREFIX):
                try:
                    new_size = MR_SIZE[label.removeprefix(MR_SIZE_PREFIX)]
                except KeyError:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_size.value < size.value:
                    size = new_size
                continue
            if label.startswith(CHANGELOG_PREFIX):
                section = label.removeprefix(CHANGELOG_PREFIX)
                continue
        try:
            short_desc = process_description(item["description"])
        except ValueError as e:
            logging.warning(f"Error processing the description for "
                            f"{item['iid']}: {e}")
            short_desc = item["title"]
        author = item["author"]["name"]
        reviewers = []
        for reviewer in item["reviewers"]:
            reviewers.append(reviewer["name"])
        if section not in processed_data[mr_type]:
            processed_data[mr_type][section] = []
        processed_data[mr_type][section].append(MergeRequestInfo(
            iid=item["iid"], size=size, author=author, reviewers=reviewers,
            short_desc=short_desc, web_url=item["web_url"]))
    return processed_data


def draft_releasenotes(fp: TextIO, data: dict[MR_TYPE, dict[str, list[MergeRequestInfo]]]) -> None:
    fp.writelines(["Release Notes\n", "===\n", "\n"])
    for mr_type, sectioned_mr_data in data.items():
        type_written = False
        for section, merge_requests in sectioned_mr_data.items():
            formatted_items = []
            merge_requests.sort(key=lambda x: x.size.value)
            for item in merge_requests:
                author = item.author
                reviewer_str = ""
                if item.reviewers:
                    reviewer_str = ", Reviewer(s): " + ", ".join(item.reviewers)
                formatted_items.append(f"- {item.short_desc} (Author: {author}{reviewer_str})"
                                       f" [{item.iid}]({item.web_url})\n")
            if formatted_items:
                if not type_written:
                    fp.writelines([f"{mr_type.name}\n", "---\n"])
                    type_written = True
                fp.writelines([f"### {section}\n", *formatted_items])
                fp.write("\n")


def main() -> None:
    release_timestamp_str = get_time_of_latest_release()
    release_timestamp = datetime.fromisoformat(release_timestamp_str)
    merge_requests = get_merge_requests(release_timestamp_str)
    processed_data = process(release_timestamp, merge_requests)
    with open(f"RN_draft_since_{release_timestamp_str}.md", "w") as f:
        draft_releasenotes(f, processed_data)


if __name__ == "__main__":
    main()
