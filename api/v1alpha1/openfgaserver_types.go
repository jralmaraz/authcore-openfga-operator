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

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json:"-" or json:"fieldName" tags for the fields to be serialized.

// OpenFGAServerSpec defines the desired state of OpenFGAServer
type OpenFGAServerSpec struct {
	// Image is the OpenFGA server container image to use
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern="^[a-zA-Z0-9][a-zA-Z0-9._/-]*:[a-zA-Z0-9._-]+$"
	Image string `json:"image"`

	// Replicas is the number of OpenFGA server instances to run
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	// +kubebuilder:default=1
	Replicas *int32 `json:"replicas,omitempty"`

	// Port is the port on which the OpenFGA server listens
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=8080
	Port *int32 `json:"port,omitempty"`

	// GRPCPort is the gRPC port on which the OpenFGA server listens
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	// +kubebuilder:default=8081
	GRPCPort *int32 `json:"grpcPort,omitempty"`

	// Database configuration for OpenFGA
	Database DatabaseConfig `json:"database"`

	// Resources defines the resource requirements for OpenFGA server pods
	Resources *corev1.ResourceRequirements `json:"resources,omitempty"`

	// Security context for the OpenFGA server pods
	SecurityContext *corev1.PodSecurityContext `json:"securityContext,omitempty"`

	// ServiceAccountName is the name of the ServiceAccount to use for OpenFGA pods
	ServiceAccountName string `json:"serviceAccountName,omitempty"`

	// OpenTelemetry configuration for observability
	OpenTelemetry *OpenTelemetryConfig `json:"openTelemetry,omitempty"`

	// NetworkPolicy configuration for Cilium integration
	NetworkPolicy *NetworkPolicyConfig `json:"networkPolicy,omitempty"`

	// Configuration for the OpenFGA server
	Config *OpenFGAConfig `json:"config,omitempty"`

	// Tolerations for pod scheduling
	Tolerations []corev1.Toleration `json:"tolerations,omitempty"`

	// NodeSelector for pod scheduling
	NodeSelector map[string]string `json:"nodeSelector,omitempty"`

	// Affinity for pod scheduling
	Affinity *corev1.Affinity `json:"affinity,omitempty"`
}

// DatabaseConfig defines the database configuration for OpenFGA
type DatabaseConfig struct {
	// Type of database (postgres, mysql, sqlite)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=postgres;mysql;sqlite
	Type string `json:"type"`

	// Host is the database host
	Host string `json:"host,omitempty"`

	// Port is the database port
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	Port *int32 `json:"port,omitempty"`

	// Database name
	Database string `json:"database,omitempty"`

	// Username for database authentication
	Username string `json:"username,omitempty"`

	// PasswordSecret contains the reference to the secret containing the database password
	PasswordSecret *corev1.SecretKeySelector `json:"passwordSecret,omitempty"`

	// SSLMode for database connection
	// +kubebuilder:validation:Enum=disable;require;verify-ca;verify-full
	SSLMode string `json:"sslMode,omitempty"`

	// MaxOpenConns is the maximum number of open connections to the database
	// +kubebuilder:validation:Minimum=1
	MaxOpenConns *int32 `json:"maxOpenConns,omitempty"`

	// MaxIdleConns is the maximum number of idle connections to the database
	// +kubebuilder:validation:Minimum=1
	MaxIdleConns *int32 `json:"maxIdleConns,omitempty"`
}

// OpenTelemetryConfig defines OpenTelemetry configuration for observability
type OpenTelemetryConfig struct {
	// Enabled indicates whether OpenTelemetry is enabled
	// +kubebuilder:default=true
	Enabled *bool `json:"enabled,omitempty"`

	// ServiceName for OpenTelemetry traces
	ServiceName string `json:"serviceName,omitempty"`

	// Endpoint for the OpenTelemetry collector
	Endpoint string `json:"endpoint,omitempty"`

	// SamplingRate for traces (0.0 to 1.0)
	// +kubebuilder:validation:Minimum=0.0
	// +kubebuilder:validation:Maximum=1.0
	SamplingRate *float64 `json:"samplingRate,omitempty"`

	// Headers to add to OpenTelemetry exports
	Headers map[string]string `json:"headers,omitempty"`
}

// NetworkPolicyConfig defines network policy configuration for Cilium integration
type NetworkPolicyConfig struct {
	// Enabled indicates whether network policies should be created
	// +kubebuilder:default=false
	Enabled *bool `json:"enabled,omitempty"`

	// AllowedIngress defines allowed ingress rules
	AllowedIngress []NetworkPolicyRule `json:"allowedIngress,omitempty"`

	// AllowedEgress defines allowed egress rules
	AllowedEgress []NetworkPolicyRule `json:"allowedEgress,omitempty"`

	// CiliumLabels are labels for Cilium-specific policies
	CiliumLabels map[string]string `json:"ciliumLabels,omitempty"`
}

// NetworkPolicyRule defines a network policy rule
type NetworkPolicyRule struct {
	// From defines the source of the rule
	From []NetworkPolicyPeer `json:"from,omitempty"`

	// To defines the destination of the rule
	To []NetworkPolicyPeer `json:"to,omitempty"`

	// Ports defines the allowed ports
	Ports []NetworkPolicyPort `json:"ports,omitempty"`
}

// NetworkPolicyPeer defines a network policy peer
type NetworkPolicyPeer struct {
	// PodSelector selects pods
	PodSelector *metav1.LabelSelector `json:"podSelector,omitempty"`

	// NamespaceSelector selects namespaces
	NamespaceSelector *metav1.LabelSelector `json:"namespaceSelector,omitempty"`

	// IPBlock defines an IP block
	IPBlock *NetworkPolicyIPBlock `json:"ipBlock,omitempty"`
}

// NetworkPolicyIPBlock defines an IP block for network policies
type NetworkPolicyIPBlock struct {
	// CIDR is the IP block in CIDR notation
	CIDR string `json:"cidr"`

	// Except is a list of IP ranges to exclude
	Except []string `json:"except,omitempty"`
}

// NetworkPolicyPort defines a port for network policies
type NetworkPolicyPort struct {
	// Protocol is the network protocol (TCP, UDP, SCTP)
	Protocol *corev1.Protocol `json:"protocol,omitempty"`

	// Port is the port number or name
	Port *int32 `json:"port,omitempty"`

	// EndPort is the end of a port range
	EndPort *int32 `json:"endPort,omitempty"`
}

// OpenFGAConfig defines configuration options for the OpenFGA server
type OpenFGAConfig struct {
	// LogLevel sets the logging level
	// +kubebuilder:validation:Enum=debug;info;warn;error
	// +kubebuilder:default="info"
	LogLevel string `json:"logLevel,omitempty"`

	// LogFormat sets the logging format
	// +kubebuilder:validation:Enum=text;json
	// +kubebuilder:default="json"
	LogFormat string `json:"logFormat,omitempty"`

	// MaxTuplesPerWrite limits the number of tuples per write request
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10000
	MaxTuplesPerWrite *int32 `json:"maxTuplesPerWrite,omitempty"`

	// MaxAuthorizationModelSizeInBytes limits the size of authorization models
	// +kubebuilder:validation:Minimum=1024
	MaxAuthorizationModelSizeInBytes *int64 `json:"maxAuthorizationModelSizeInBytes,omitempty"`

	// PlaygroundEnabled enables the OpenFGA playground
	// +kubebuilder:default=false
	PlaygroundEnabled *bool `json:"playgroundEnabled,omitempty"`

	// HTTPConfig defines HTTP server configuration
	HTTPConfig *HTTPConfig `json:"httpConfig,omitempty"`

	// GRPCConfig defines gRPC server configuration
	GRPCConfig *GRPCConfig `json:"grpcConfig,omitempty"`
}

// HTTPConfig defines HTTP server configuration
type HTTPConfig struct {
	// ReadTimeout for HTTP requests
	ReadTimeout *metav1.Duration `json:"readTimeout,omitempty"`

	// WriteTimeout for HTTP responses
	WriteTimeout *metav1.Duration `json:"writeTimeout,omitempty"`

	// IdleTimeout for HTTP connections
	IdleTimeout *metav1.Duration `json:"idleTimeout,omitempty"`

	// ReadHeaderTimeout for HTTP request headers
	ReadHeaderTimeout *metav1.Duration `json:"readHeaderTimeout,omitempty"`

	// CORSAllowedOrigins for CORS configuration
	CORSAllowedOrigins []string `json:"corsAllowedOrigins,omitempty"`

	// CORSAllowedHeaders for CORS configuration
	CORSAllowedHeaders []string `json:"corsAllowedHeaders,omitempty"`
}

// GRPCConfig defines gRPC server configuration
type GRPCConfig struct {
	// Enabled indicates whether gRPC server is enabled
	// +kubebuilder:default=true
	Enabled *bool `json:"enabled,omitempty"`

	// TLSConfig for gRPC TLS configuration
	TLSConfig *TLSConfig `json:"tlsConfig,omitempty"`
}

// TLSConfig defines TLS configuration
type TLSConfig struct {
	// Enabled indicates whether TLS is enabled
	// +kubebuilder:default=false
	Enabled *bool `json:"enabled,omitempty"`

	// CertSecret contains the reference to the secret containing TLS certificates
	CertSecret *corev1.SecretKeySelector `json:"certSecret,omitempty"`

	// KeySecret contains the reference to the secret containing TLS private key
	KeySecret *corev1.SecretKeySelector `json:"keySecret,omitempty"`
}

// OpenFGAServerStatus defines the observed state of OpenFGAServer
type OpenFGAServerStatus struct {
	// Conditions represent the latest available observations of the OpenFGA server's current state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// Phase represents the current phase of the OpenFGA server
	// +kubebuilder:validation:Enum=Pending;Running;Failed;Unknown
	Phase string `json:"phase,omitempty"`

	// ReadyReplicas is the number of ready replicas
	ReadyReplicas int32 `json:"readyReplicas,omitempty"`

	// Replicas is the total number of replicas
	Replicas int32 `json:"replicas,omitempty"`

	// ObservedGeneration reflects the generation of the most recently observed OpenFGAServer
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// ServiceURL is the URL where the OpenFGA service is accessible
	ServiceURL string `json:"serviceURL,omitempty"`

	// GRPCServiceURL is the URL where the OpenFGA gRPC service is accessible
	GRPCServiceURL string `json:"grpcServiceURL,omitempty"`

	// LastReconcileTime is the last time the resource was reconciled
	LastReconcileTime *metav1.Time `json:"lastReconcileTime,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:subresource:scale:specpath=.spec.replicas,statuspath=.status.replicas,selectorpath=.status.selector
// +kubebuilder:printcolumn:name="Ready",type="string",JSONPath=".status.readyReplicas"
// +kubebuilder:printcolumn:name="Replicas",type="string",JSONPath=".spec.replicas"
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
// +kubebuilder:printcolumn:name="Service URL",type="string",JSONPath=".status.serviceURL"

// OpenFGAServer is the Schema for the openfgaservers API
type OpenFGAServer struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   OpenFGAServerSpec   `json:"spec,omitempty"`
	Status OpenFGAServerStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// OpenFGAServerList contains a list of OpenFGAServer
type OpenFGAServerList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []OpenFGAServer `json:"items"`
}

func init() {
	SchemeBuilder.Register(&OpenFGAServer{}, &OpenFGAServerList{})
}
