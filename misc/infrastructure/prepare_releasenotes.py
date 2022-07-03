from enum import Enum
import logging
import requests
from typing import NamedTuple, TextIO

# TODO: remove after testing
import os
import json
# end remove after testing


# value indicates prio, lower prio is prefered in RN if more than one topic is given
# TODO: these topics are overlapping and also too specific
TOPIC = Enum("TOPIC", {"Accessibility": 1,
                       "Audio": 2,
                       "Balance": 3,
                       "Bots": 4,
                       "Build": 5,
                       "Campaign": 6,
                       "Client": 7,
                       "Configuration": 8,
                       "Console": 9,
                       "Documentation": 10,
                       "Engine": 11,
                       "Gamelogic": 12,
                       "Gameplay": 13,
                       "HUD": 14,
                       "Input": 15,
                       "Mapping": 16,
                       "Menu": 17,
                       "Moderation": 18,
                       "Network": 19,
                       "Performance": 20,
                       "Physics": 21,
                       "Rendering": 22,
                       "Server": 23,
                       "Shaders & Textures": 24,
                       "Stats": 25,
                       "Turrets": 26,
                       "Tutorial": 27,
                       "Vehicles": 28,
                       "Weapons": 29,
                       "i18n (translations)": 30,
                       "NO_TOPIC": 9999})
# TODO: use these instead
SECTION = Enum("SECTION", {"Gameplay": 1,
                           "Balance": 2,
                           "Mapping": 3,
                           "Assets": 4,
                           "Menu": 5,
                           "Client": 6,
                           "Server": 7,
                           "Bots": 8,
                           "Stats": 9,
                           "Engine": 10,
                           "i18n (translations)": 11,
                           "Documentation": 12,
                           "Infrastructure": 13,
                           "NO_SECTION": 9999})

MR_TYPE = Enum("MR_TYPE", {"Bug fix": 1,
                           "Refactor": 2,
                           "UNKNOWN_TYPE": 9999})
# TODO: use these instead
#MR_TYPE = Enum("MR_TYPE", {"Feature/Addition": 1,
#                           "Change": 2,
#                           "Bug fix for latest release": 3,
#                           "Bug fix for git": 4,
#                           "Refactor": 5,
#                           "Misc": 6,
#                           "UNKNOWN_TYPE": 9999})

# for ordering
MR_SIZE = Enum("MR_SIZE", {"Enormous": 1,
                           "Large": 2,
                           "Medium": 3,
                           "Small": 4,
                           "Tiny": 5,
                           "UNKNOWN": 6})

TOPIC_PREFIX = "Topic: "
CHANGELOG_PREFIX = "Changelog::"
MR_TYPE_PREFIX = "MR Type: "
MR_SIZE_PREFIX = "MR Size::"
BUGFIX_REFERENCE_PREFIX = "Bug introduced in MR (for 'Bug fix for git' types only): "

MAIN_PROJECT_ID = 73434
EXCLUDED_PROJECT_IDS = []
TARGET_BRANCHES = ["master", "develop", "pending-release"]

GROUP_NAME = "xonotic"
BASEURL = "https://gitlab.com/api/v4"
MAIN_PROJECT_BASEURL = BASEURL + f"/projects/{MAIN_PROJECT_ID}/repository"
GROUP_BASEURL = BASEURL + f"/groups/{GROUP_NAME}"


class MergeRequestInfo(NamedTuple):
    iid: int
    mr_type: MR_TYPE
    size: MR_SIZE
    topic: TOPIC
    section: SECTION
    author: str
    short_desc: str
    web_url: str
    reference: int


def get_time_of_latest_release() -> str:
    response = requests.get(MAIN_PROJECT_BASEURL + "/tags")
    latest = response.json()[0]
    return latest["commit"]["created_at"]


def get_merge_requests(timestamp: str) -> list[dict]:
    if os.path.isfile("testdata.json"):
        with open("testdata.json") as f:
            return json.load(f)
    page_len = 10
    MAX_PAGES = 1 # TODO: increase after testing
    url = GROUP_BASEURL + f"/merge_requests?state=merged&updated_after=" +\
          f"{timestamp}&per_page={page_len}&page="
    current_page = 1
    data = []
    while True:
        response = requests.get(url+str(current_page))
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


def process_description(description: str, mr_type: MR_TYPE) -> tuple[str, int]:
    if not description:
        raise ValueError("Empty description")
    lines = description.splitlines()
    if not lines[0].strip() == "Summary for release notes:":
        raise ValueError("Unexpected description format: Summary missing")
    summary = ""
    cursor = 0
    for i, line in enumerate(lines[1:]):
        if line.startswith("---"):
            continue
        if not line:
            cursor = i
            break
        summary += line + " " # add space
    if mr_type != MR_TYPE["Bug fix"]: # should be "Bug fix for git"
        return summary.strip(), 0
    reference = 0
    for line in lines[cursor:]:
        if line.startswith(BUGFIX_REFERENCE_PREFIX):
            temp = line.removeprefix(BUGFIX_REFERENCE_PREFIX).strip().lstrip("!")
            if not temp.isdecimal():
                logging.warning("Expected a number as MR reference, found "
                                f"'{temp}'")
                reference = temp
            else:
                reference = int(temp)
            break
    return summary.strip(), reference



def process(data: list[dict]) -> list[MergeRequestInfo]:
    # extract type, size and topic from labels for easier filtering/ordering
    # extract reference (for bugfix for git) and short description from description
    # extract author->name
    processed_data = []
    for item in data:
        if item["project_id"] in EXCLUDED_PROJECT_IDS:
            continue
        if item["target_branch"] not in TARGET_BRANCHES:
            continue
        mr_type = MR_TYPE.UNKNOWN_TYPE
        size = MR_SIZE.UNKNOWN
        topic = TOPIC.NO_TOPIC
        section = SECTION.NO_SECTION
        for label in item["labels"]:
            if label.startswith(MR_TYPE_PREFIX):
                try:
                    new_mr_type = MR_TYPE[label.removeprefix(MR_TYPE_PREFIX)]
                except KeyError as e:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_mr_type.value < mr_type.value:
                    mr_type = new_mr_type
                continue
            if label.startswith(MR_SIZE_PREFIX):
                try:
                    new_size = MR_SIZE[label.removeprefix(MR_SIZE_PREFIX)]
                except KeyError as e:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_size.value < size.value:
                    size = new_size
                continue
            if label.startswith(TOPIC_PREFIX):
                try:
                    new_topic = TOPIC[label.removeprefix(TOPIC_PREFIX)]
                except KeyError as e:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_topic.value < topic.value:
                    topic = new_topic
                continue
            if label.startswith(CHANGELOG_PREFIX):
                try:
                    new_section = SECTION[label.removeprefix(CHANGELOG_PREFIX)]
                except KeyError as e:
                    logging.warning(f"Unexpected label: {label}, skipping")
                    continue
                if new_section.value < section.value:
                    section = new_section
                continue
        # TODO: uncomment once new MR Type labels are used
        #if mr_type == MR_TYPE.Misc:
        #    continue
        try:
            short_desc, referenced_mr = process_description(item["description"],
                                                            mr_type)
        except ValueError as e:
            logging.warning(f"Error processing the description for "
                            f"{item['iid']}: {e}")
            short_desc = item["title"]
            referenced_mr = 0
        author = item["author"]["name"]
        processed_data.append(MergeRequestInfo(iid=item["iid"],
                                               mr_type=mr_type,
                                               size=size,
                                               topic=topic,
                                               section=section,
                                               author=author,
                                               short_desc=short_desc,
                                               web_url=item["web_url"],
                                               reference=referenced_mr))
    processed_data.sort(key=lambda x: x.size.value)
    return processed_data


def draft_releasenotes(fp: TextIO, data: list[MergeRequestInfo]) -> None:
    fp.writelines(["Release Notes\n", "===\n", "\n"])
    for mr_type in MR_TYPE:
        type_written = False
        #for section in SECTION:
        for topic in TOPIC:
            formatted_items = []
            #filtered = filter(lambda x: x.mr_type==mr_type and x.section==section,
            #                  data)
            filtered = filter(lambda x: x.mr_type==mr_type and x.topic==topic,
                              data)
            for item in filtered:
                if item.reference != 0:
                    continue
                authors = item.author
                referenced_by = filter(lambda x: x.reference==item.iid, data)
                fix_authors = set()
                for other_mr in referenced_by:
                    fix_authors.append(other_mr.author)
                if item.author in fix_authors:
                    fix_authors.remove(item.author)
                if fix_authors:
                    authors += ", fixes by " + ", ".join(fix_authors)
                formatted_items.append(f"- {item.short_desc} by {authors} "
                                       f"([{item.iid}]({item.web_url}))\n")
            if formatted_items:
                if not type_written:
                    fp.writelines([f"{mr_type.name}\n", "---\n"])
                    type_written = True
                #fp.writelines([f"### {section.name}\n", *formatted_items])
                fp.writelines([f"### {topic.name}\n", *formatted_items])
                fp.write("\n")


def main() -> None:
    release_timestamp = get_time_of_latest_release()
    merge_requests = get_merge_requests(release_timestamp)
    processed_data = process(merge_requests)
    with open(f"RN_draft_since_{release_timestamp}.md", "w") as f:
        draft_releasenotes(f, processed_data)


if __name__ == "__main__":
    main()
