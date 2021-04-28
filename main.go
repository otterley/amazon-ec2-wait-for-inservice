package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"math"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/aws-sdk-go-v2/service/autoscaling"
)

const (
	DefaultSleepInterval = 15 * time.Second
)

type Config struct {
	SleepInterval time.Duration
}

func parseArgs() (*Config, error) {
	sleepInterval := flag.Int("sleepInterval", int(DefaultSleepInterval/time.Second), "Sleep Interval")
	flag.Parse()
	if *sleepInterval <= 0 {
		return nil, errors.New("sleepInterval must be a positive integer")
	}
	return &Config{
		SleepInterval: time.Duration(*sleepInterval) * time.Second,
	}, nil
}

func main() {
	cfg, err := parseArgs()
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.TODO()

	awscfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("%v", err)
	}

	var instanceIdentity *imds.GetInstanceIdentityDocumentOutput
	for {
		// Get instance identity
		// Retry as needed. For some reason, configuring Retryer options here doesn't work.
		i := imds.NewFromConfig(awscfg)
		instanceIdentity, err = i.GetInstanceIdentityDocument(context.TODO(), &imds.GetInstanceIdentityDocumentInput{})
		if err == nil {
			break
		}
		log.Printf("Unable to load instance identity: %v - will retry in %d seconds", err, cfg.SleepInterval / time.Second)
		time.Sleep(cfg.SleepInterval)
	}

	log.Printf("Instance ID is %s\n", instanceIdentity.InstanceID)
	log.Println("Polling Auto Scaling status...")

	svc := autoscaling.NewFromConfig(awscfg, func(options *autoscaling.Options) {
		options.Region = instanceIdentity.Region
	})

	// Main loop
	for {
		instances, err := svc.DescribeAutoScalingInstances(ctx, &autoscaling.DescribeAutoScalingInstancesInput{
			InstanceIds: []string{
				instanceIdentity.InstanceID,
			},
		}, func(options *autoscaling.Options) {
			// Retry transient errors
			options.Retryer = retry.AddWithMaxAttempts(options.Retryer, math.MaxInt64)
		})
		if err != nil {
			log.Fatalf("%v", err)
		}

		if len(instances.AutoScalingInstances) == 0 {
			log.Println("Instance is not in an Auto Scaling Group. Exiting successfully.")
			os.Exit(0)
		}

		lifecycleState := aws.ToString(instances.AutoScalingInstances[0].LifecycleState)
		if os.Getenv("DEBUG") != "" {
			log.Printf("Lifecycle state: %s\n", lifecycleState)
		}

		if lifecycleState == "InService" {
			log.Println("Instance is now InService. Exiting successfully.")
			os.Exit(0)
		}

		time.Sleep(cfg.SleepInterval)
	}
}
