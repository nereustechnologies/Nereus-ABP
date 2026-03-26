import boto3
import os
import zipfile
import argparse
from pathlib import Path


def download_csvs(bucket, prefix, profile, output_dir):
    # Create session using AWS profile
    session = boto3.Session(profile_name=profile)
    s3 = session.client("s3")

    paginator = s3.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        if "Contents" not in page:
            continue

        for obj in page["Contents"]:
            key = obj["Key"]

            # Only download CSV files
            if not key.endswith(".csv"):
                continue

            local_path = os.path.join(output_dir, key)

            os.makedirs(os.path.dirname(local_path), exist_ok=True)

            print(f"Downloading {key}")
            s3.download_file(bucket, key, local_path)


def zip_folder(folder_path, zip_name):
    with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                full_path = os.path.join(root, file)
                arcname = os.path.relpath(full_path, folder_path)
                zipf.write(full_path, arcname)

    print(f"ZIP created: {zip_name}")


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--bucket", required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--output", default="downloaded_files")
    parser.add_argument("--zip", default="s3_download.zip")

    args = parser.parse_args()

    Path(args.output).mkdir(parents=True, exist_ok=True)

    download_csvs(
        bucket=args.bucket,
        prefix=args.prefix,
        profile=args.profile,
        output_dir=args.output,
    )

    zip_folder(args.output, args.zip)


if __name__ == "__main__":
    main()