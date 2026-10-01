# EC2 backup and recovery

## Backup

- Instance: `nginx-website` / `i-00503c53ba2290213`
- Region: Mumbai / `ap-south-1`
- Root volume: `vol-08d7a49229a292a04`, 8 GiB
- Snapshot: `snap-0c440a92d3fb261c1`
- Created: 2026-09-09 06:50:53 UTC (12:20:53 PM India time)
- Encrypted: yes
- Contents: disk data including the Python app, dependencies, systemd service, and Nginx configuration

Taken while the instance was running. Pending memory writes are not included; application consistency is not guaranteed. For a future database or other write-heavy application, quiesce writes or stop the instance before taking the snapshot. This is a one-time backup, not an automated recurring policy. Snapshot storage charges apply. Keep access to the encryption key.

Check completion:

```powershell
. .\aws-query.ps1
$r = Invoke-AwsQuery DescribeSnapshots @{'SnapshotId.1'='snap-0c440a92d3fb261c1'}
$r.DescribeSnapshotsResponse.snapshotSet.item | Select-Object snapshotId,status,progress
```

## Restore files when needed

1. Open EC2 in Mumbai → Snapshots and select this snapshot. Wait for **Completed**.
2. Choose **Actions → Create volume from snapshot**, select **gp3**, at least **8 GiB**, and the recovery instance's Availability Zone. The current website instance is in `ap-south-1a`.
3. Wait for the new volume to become **Available**, then attach it as a secondary disk to a Linux recovery instance in that Availability Zone.
4. Connect to the recovery instance. Use `lsblk -f` and EBS volume identifiers to identify the restored disk and partition. Nitro instances expose disks as NVMe devices; do not assume the requested attachment name is the Linux device name.
5. Do **not** format the restored disk. Mount its filesystem read-only. For XFS, use `sudo mount -o ro,nouuid,norecovery /dev/RESTORED_PARTITION /mnt/recovery` after creating `/mnt/recovery`. Replace the placeholder with the verified partition. Use filesystem-appropriate options if it is not XFS.
6. Inspect `/mnt/recovery/opt/ec2-python-app/app.py` and other required files, then copy selected files to a safe destination. Verify the recovered files before overwriting live data.
7. Unmount and detach the recovery volume after recovery. Delete that temporary volume only when the recovered data has been verified; retain the snapshot according to your retention needs.

## Restore the full root disk when needed

This rolls the website back to the backup date and requires downtime.

1. Record the current instance configuration and volume attachment. Create a fresh safety snapshot of the current root volume.
2. Temporarily disable both `nginx-website-daily-start` and `nginx-website-daily-stop` in EventBridge Scheduler to prevent interference; record their enabled states.
3. Create a new encrypted gp3 volume from the completed backup in `ap-south-1a` and wait until available.
4. Stop the instance and wait for **Stopped**. Detach the existing root volume, retaining it for rollback.
5. Attach the restored volume to the instance using the original root device name, `/dev/xvda`.
6. Start the instance. Check EC2 status checks, look up its current public IP, and verify `/`, `/health`, and `/api/info`. Check `systemctl status ec2-python-app nginx` if necessary.
7. Restore the schedules to their previous enabled states. Review the replacement volume's delete-on-termination setting. Retain the old volume until recovery is accepted; retained volumes incur charges.

EBS snapshots do not back up EventBridge schedules, CloudWatch alarms, IAM roles, or security group definitions. Their setup scripts are stored separately in this workspace. No live disk replacement or restore test was performed for this backup.

AWS references: [Create snapshots](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-creating-snapshot.html), [EBS snapshots and restoration](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html).
