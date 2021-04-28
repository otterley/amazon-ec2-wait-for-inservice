# Example solution for deferring Amazon EC2 Auto Scaling Warm Pool instance startup actions

This repository contains example code and configuration that can be used to
defer certain Amazon EC2 instance startup actions. It is particularly useful
when launching an instance into an EC2 Auto Scaling Warm Pool.

For example, if the instance will eventually join an Amazon ECS or EKS cluster,
you might want to defer doing so until the instance is in the `InService` state.
This avoids accidents like having the instance join the cluster early, while it
is being prepared to enter the Warm Pool.

## Deferring application start

In this example, we employ a systemd [drop-in
unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
configuration to override application startup dependencies (in this example, the
Amazon ECS agent). By declaring a
[`Requires`](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Requires=)
dependency upon a blocking service, along with an
[`After`](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Before=)
ordering upon it, we can prevent the dependent application from starting until
the Auto Scaling status indicates the instance is ready for the application to
start.

## Contents

### amazon-ec2-wait-for-inservice

`amazon-ec2-wait-for-inservice` is a small program, written in Go, that polls
the EC2 Auto Scaling API and waits until the instance on which it is running
reports that it is in the `InService` state. Once that state has been reached,
it exits successfully.

### Packer configuration template

`ami.pkr.hcl` is a Packer template that constructs a set of modified Amazon
ECS and EKS Optimized AMIs, one for each EC2 CPU architecture (amd64 and arm64). The
`amazon-ec2-wait-for-inservice` application is copied to each AMI along with the
relevant systemd configuration.

### systemd units and drop-ins

See the systemd/ folder for the units and drop-ins needed to complete the solution.

## IAM requirements

The EC2 instance profile's role must allow the action `autoscaling:DescribeAutoScalingInstances`.
## Disclaimer and warnings

This is a proof of concept and should not be considered production-ready. There
may be bugs.

This solution will place additional query load on the EC2 Auto Scaling API. At
large scale, where there are many EC2 instances starting at once in a single
account, this may cause API rate limit exhaustion. If this occurs, the
application tries to fail safe (that is, it won't accidentally start the
dependent application). The application employs retries with exponential backoff
and jitter, but it may take time for the API to become available again if a rate
limit is encountered.