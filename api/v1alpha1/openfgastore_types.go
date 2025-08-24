/*
Copyright 2023.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// OpenFGAStoreSpec defines the desired state of OpenFGAStore
type OpenFGAStoreSpec struct {
	// ServerRef is a reference to the OpenFGAServer where this store will be created
	// +kubebuilder:validation:Required
	ServerRef ServerReference `json:"serverRef"`

	// DisplayName is a human-readable name for the store
	DisplayName string `json:"displayName,omitempty"`

	// Description provides additional information about the store
	Description string `json:"description,omitempty"`

	// RetentionPolicy defines the data retention policy for the store
	RetentionPolicy *RetentionPolicy `json:"retentionPolicy,omitempty"`

	// AccessControl defines access control settings for the store
	AccessControl *AccessControl `json:"accessControl,omitempty"`

	// OpenTelemetry configuration for observability
	OpenTelemetry *OpenTelemetryConfig `json:"openTelemetry,omitempty"`

	// Backup configuration for the store
	Backup *BackupConfig `json:"backup,omitempty"`

	// Metrics configuration for the store
	Metrics *MetricsConfig `json:"metrics,omitempty"`

	// Labels to be applied to the store
	Labels map[string]string `json:"labels,omitempty"`

	// Annotations to be applied to the store
	Annotations map[string]string `json:"annotations,omitempty"`
}

// RetentionPolicy defines data retention settings for a store
type RetentionPolicy struct {
	// Enabled indicates whether data retention is enabled
	// +kubebuilder:default=false
	Enabled *bool `json:"enabled,omitempty"`

	// TupleRetentionDays defines how long tuples should be retained
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=3650
	TupleRetentionDays *int32 `json:"tupleRetentionDays,omitempty"`

	// ModelRetentionDays defines how long authorization models should be retained
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=3650
	ModelRetentionDays *int32 `json:"modelRetentionDays,omitempty"`

	// LogRetentionDays defines how long audit logs should be retained
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=3650
	LogRetentionDays *int32 `json:"logRetentionDays,omitempty"`

	// AutoCleanup indicates whether automatic cleanup should be performed
	// +kubebuilder:default=true
	AutoCleanup *bool `json:"autoCleanup,omitempty"`
}

// AccessControl defines access control settings for a store
type AccessControl struct {
	// Enabled indicates whether access control is enabled
	// +kubebuilder:default=true
	Enabled *bool `json:"enabled,omitempty"`

	// AllowedServiceAccounts lists the service accounts that can access this store
	AllowedServiceAccounts []string `json:"allowedServiceAccounts,omitempty"`

	// AllowedUsers lists the users that can access this store
	AllowedUsers []string `json:"allowedUsers,omitempty"`

	// AllowedGroups lists the groups that can access this store
	AllowedGroups []string `json:"allowedGroups,omitempty"`

	// NetworkPolicies defines network access policies
	NetworkPolicies []NetworkPolicyRule `json:"networkPolicies,omitempty"`

	// RBACRules defines RBAC rules for the store
	RBACRules []RBACRule `json:"rbacRules,omitempty"`
}

// RBACRule defines an RBAC rule for store access
type RBACRule struct {
	// Subjects are the users, groups, or service accounts this rule applies to
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinItems=1
	Subjects []RBACSubject `json:"subjects"`

	// Permissions are the permissions granted to the subjects
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinItems=1
	Permissions []string `json:"permissions"`

	// Resources are the resources this rule applies to
	Resources []string `json:"resources,omitempty"`

	// Conditions are additional conditions for the rule
	Conditions map[string]string `json:"conditions,omitempty"`
}

// RBACSubject defines a subject for RBAC rules
type RBACSubject struct {
	// Kind is the kind of subject (User, Group, ServiceAccount)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=User;Group;ServiceAccount
	Kind string `json:"kind"`

	// Name is the name of the subject
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Namespace is the namespace of the subject (for ServiceAccount)
	Namespace string `json:"namespace,omitempty"`
}

// BackupConfig defines backup configuration for a store
type BackupConfig struct {
	// Enabled indicates whether backups are enabled
	// +kubebuilder:default=false
	Enabled *bool `json:"enabled,omitempty"`

	// Schedule defines the backup schedule in cron format
	// +kubebuilder:validation:Pattern="^(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-]\\d+)?)|\\*) ){4,6}(((\\d+,)+\\d+|(\\d+([/\\-]\\d+)?)|\\*)( |$)))$"
	Schedule string `json:"schedule,omitempty"`

	// RetentionCount is the number of backups to retain
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=100
	RetentionCount *int32 `json:"retentionCount,omitempty"`

	// StorageClass for backup persistent volumes
	StorageClass string `json:"storageClass,omitempty"`

	// StorageSize for backup persistent volumes
	StorageSize string `json:"storageSize,omitempty"`

	// Compression indicates whether backups should be compressed
	// +kubebuilder:default=true
	Compression *bool `json:"compression,omitempty"`

	// Encryption configuration for backups
	Encryption *EncryptionConfig `json:"encryption,omitempty"`
}

// EncryptionConfig defines encryption configuration
type EncryptionConfig struct {
	// Enabled indicates whether encryption is enabled
	// +kubebuilder:default=false
	Enabled *bool `json:"enabled,omitempty"`

	// Algorithm is the encryption algorithm to use
	// +kubebuilder:validation:Enum=AES256;AES128;ChaCha20Poly1305
	Algorithm string `json:"algorithm,omitempty"`

	// KeySecret contains the reference to the secret containing the encryption key
	KeySecret *corev1.SecretKeySelector `json:"keySecret,omitempty"`
}

// MetricsConfig defines metrics configuration for a store
type MetricsConfig struct {
	// Enabled indicates whether metrics collection is enabled
	// +kubebuilder:default=true
	Enabled *bool `json:"enabled,omitempty"`

	// Interval defines the metrics collection interval
	// +kubebuilder:default="30s"
	Interval *metav1.Duration `json:"interval,omitempty"`

	// CustomMetrics defines custom metrics to collect
	CustomMetrics []CustomMetric `json:"customMetrics,omitempty"`

	// PrometheusConfig defines Prometheus-specific configuration
	PrometheusConfig *PrometheusConfig `json:"prometheusConfig,omitempty"`
}

// CustomMetric defines a custom metric to collect
type CustomMetric struct {
	// Name is the name of the metric
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Type is the type of metric (counter, gauge, histogram)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=counter;gauge;histogram
	Type string `json:"type"`

	// Description provides a description of the metric
	Description string `json:"description,omitempty"`

	// Labels are additional labels for the metric
	Labels map[string]string `json:"labels,omitempty"`
}

// PrometheusConfig defines Prometheus-specific configuration
type PrometheusConfig struct {
	// ServiceMonitor indicates whether a ServiceMonitor should be created
	// +kubebuilder:default=true
	ServiceMonitor *bool `json:"serviceMonitor,omitempty"`

	// Namespace for the ServiceMonitor
	ServiceMonitorNamespace string `json:"serviceMonitorNamespace,omitempty"`

	// Labels for the ServiceMonitor
	ServiceMonitorLabels map[string]string `json:"serviceMonitorLabels,omitempty"`

	// AdditionalLabels are additional labels for Prometheus metrics
	AdditionalLabels map[string]string `json:"additionalLabels,omitempty"`
}

// OpenFGAStoreStatus defines the observed state of OpenFGAStore
type OpenFGAStoreStatus struct {
	// Conditions represent the latest available observations of the store's current state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// Phase represents the current phase of the store
	// +kubebuilder:validation:Enum=Pending;Ready;Failed;Unknown
	Phase string `json:"phase,omitempty"`

	// StoreID is the ID of the store in OpenFGA
	StoreID string `json:"storeID,omitempty"`

	// ObservedGeneration reflects the generation of the most recently observed OpenFGAStore
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// LastReconcileTime is the last time the resource was reconciled
	LastReconcileTime *metav1.Time `json:"lastReconcileTime,omitempty"`

	// CreatedAt is the timestamp when the store was created
	CreatedAt *metav1.Time `json:"createdAt,omitempty"`

	// TupleCount is the approximate number of tuples in the store
	TupleCount *int64 `json:"tupleCount,omitempty"`

	// ModelCount is the number of authorization models in the store
	ModelCount *int32 `json:"modelCount,omitempty"`

	// LastBackup is the timestamp of the last successful backup
	LastBackup *metav1.Time `json:"lastBackup,omitempty"`

	// BackupStatus provides information about backup status
	BackupStatus string `json:"backupStatus,omitempty"`

	// MetricsEndpoint is the endpoint where metrics are available
	MetricsEndpoint string `json:"metricsEndpoint,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Store ID",type="string",JSONPath=".status.storeID"
// +kubebuilder:printcolumn:name="Tuples",type="integer",JSONPath=".status.tupleCount"
// +kubebuilder:printcolumn:name="Models",type="integer",JSONPath=".status.modelCount"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
// +kubebuilder:printcolumn:name="Last Backup",type="date",JSONPath=".status.lastBackup"

// OpenFGAStore is the Schema for the openfgastores API
type OpenFGAStore struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   OpenFGAStoreSpec   `json:"spec,omitempty"`
	Status OpenFGAStoreStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// OpenFGAStoreList contains a list of OpenFGAStore
type OpenFGAStoreList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []OpenFGAStore `json:"items"`
}

func init() {
	SchemeBuilder.Register(&OpenFGAStore{}, &OpenFGAStoreList{})
}
