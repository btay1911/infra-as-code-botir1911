# PROOF.md — Assignment 01: Prove It's Code

## Server code
- File: ec2.tf, in the same folder as main.tf (network code)
- Resources: aws_instance.instance, aws_security_group.sg (+ ingress/egress rules)
- Name tag: botir-assignment-01

## First apply
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
instance_public_ip = "18.208.200.163"

## SSH connection (first instance)
$ ssh -i ~/Downloads/crixsalis-key.pem ec2-user@18.208.200.163
The authenticity of host '18.208.200.163 (18.208.200.163)' can't be established.
ED25519 key fingerprint is: SHA256:teP96JaDyI2BktaimRcGp0CoiC3J3Pr99Z/BkuMCVBA
Warning: Permanently added '18.208.200.163' (ED25519) to the list of known hosts.
[ec2-user@ip-10-0-1-192 ~]$

## Destroy
Destroy complete! Resources: 12 destroyed.
Confirmed via: terraform state list (empty)

## Rebuild (second apply, same code)
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
instance_public_ip = "100.54.31.109"

Different from first IP (18.208.200.163) - same code, new machine.

## SSH connection (rebuilt instance)
$ ssh -i ~/Downloads/crixsalis-key.pem ec2-user@100.54.31.109
The authenticity of host '100.54.31.109 (100.54.31.109)' can't be established.
ED25519 key fingerprint is: SHA256:dKS53zmGRvf6R7hrniHIJ8ReNLZS8Ue+RSTdRYXqwQA
Warning: Permanently added '100.54.31.109' (ED25519) to the list of known hosts.
[ec2-user@ip-10-0-1-54 ~]$

## Final destroy
Destroy complete! Resources: 12 destroyed.
Confirmed via: terraform state list (empty), AWS Console (EC2 and VPC pages checked manually - nothing from this stack remains)

## Budget alarm
Name: Budget monthly AWS
Amount: $40.00
Status: OK / Healthy
