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

// AuthorizationModelSpec defines the desired state of AuthorizationModel
type AuthorizationModelSpec struct {
	// StoreRef is a reference to the OpenFGA store where this model will be applied
	// +kubebuilder:validation:Required
	StoreRef StoreReference `json:"storeRef"`

	// Schema defines the authorization model schema
	// +kubebuilder:validation:Required
	Schema AuthorizationSchema `json:"schema"`

	// SchemaVersion specifies the version of the authorization model schema
	// +kubebuilder:validation:Pattern="^1\\.1$"
	// +kubebuilder:default="1.1"
	SchemaVersion string `json:"schemaVersion,omitempty"`

	// Conditions defines additional conditions for the authorization model
	Conditions map[string]string `json:"conditions,omitempty"`

	// OpenTelemetry configuration for observability
	OpenTelemetry *OpenTelemetryConfig `json:"openTelemetry,omitempty"`
}

// StoreReference defines a reference to an OpenFGA store
type StoreReference struct {
	// Name is the name of the OpenFGAStore resource
	Name string `json:"name,omitempty"`

	// Namespace is the namespace of the OpenFGAStore resource
	Namespace string `json:"namespace,omitempty"`

	// StoreID is the direct OpenFGA store ID (alternative to Name/Namespace)
	StoreID string `json:"storeID,omitempty"`

	// ServerRef is a reference to the OpenFGAServer
	ServerRef ServerReference `json:"serverRef,omitempty"`
}

// ServerReference defines a reference to an OpenFGA server
type ServerReference struct {
	// Name is the name of the OpenFGAServer resource
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Namespace is the namespace of the OpenFGAServer resource
	Namespace string `json:"namespace,omitempty"`

	// Endpoint is the direct endpoint URL (alternative to Name/Namespace)
	Endpoint string `json:"endpoint,omitempty"`
}

// AuthorizationSchema defines the structure of an authorization model
type AuthorizationSchema struct {
	// TypeDefinitions define the types and their relations in the authorization model
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinItems=1
	TypeDefinitions []TypeDefinition `json:"type_definitions"`
}

// TypeDefinition defines a type and its relations in the authorization model
type TypeDefinition struct {
	// Type is the name of the type
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern="^[a-zA-Z][a-zA-Z0-9_]*$"
	Type string `json:"type"`

	// Relations define the relations for this type
	Relations map[string]Relation `json:"relations,omitempty"`

	// Metadata provides additional information about the type
	Metadata map[string]string `json:"metadata,omitempty"`
}

// Relation defines a relation in a type definition
type Relation struct {
	// This defines the relation using OpenFGA DSL
	This *RelationReference `json:"this,omitempty"`

	// Union defines a union of relations
	Union *Union `json:"union,omitempty"`

	// Intersection defines an intersection of relations
	Intersection *Intersection `json:"intersection,omitempty"`

	// Difference defines a difference between relations
	Difference *Difference `json:"difference,omitempty"`

	// TupleToUserset defines a tuple-to-userset relation
	TupleToUserset *TupleToUserset `json:"tupleToUserset,omitempty"`

	// ComputedUserset defines a computed userset relation
	ComputedUserset *ComputedUserset `json:"computedUserset,omitempty"`
}

// RelationReference defines a direct relation reference
type RelationReference struct {
	// Type is the type being referenced
	Type string `json:"type,omitempty"`

	// Relation is the relation being referenced
	Relation string `json:"relation,omitempty"`

	// Wildcard indicates if this is a wildcard relation
	Wildcard bool `json:"wildcard,omitempty"`

	// Condition is an optional condition for the relation
	Condition string `json:"condition,omitempty"`
}

// Union defines a union of relations
type Union struct {
	// Children are the relations in the union
	// +kubebuilder:validation:MinItems=2
	Children []Relation `json:"children"`
}

// Intersection defines an intersection of relations
type Intersection struct {
	// Children are the relations in the intersection
	// +kubebuilder:validation:MinItems=2
	Children []Relation `json:"children"`
}

// Difference defines a difference between relations
type Difference struct {
	// Base is the base relation
	// +kubebuilder:validation:Required
	Base Relation `json:"base"`

	// Subtract is the relation to subtract
	// +kubebuilder:validation:Required
	Subtract Relation `json:"subtract"`
}

// TupleToUserset defines a tuple-to-userset relation
type TupleToUserset struct {
	// TupleSet defines the tuple set
	// +kubebuilder:validation:Required
	TupleSet TupleSet `json:"tupleSet"`

	// ComputedUserset defines the computed userset
	// +kubebuilder:validation:Required
	ComputedUserset ComputedUserset `json:"computedUserset"`
}

// TupleSet defines a tuple set
type TupleSet struct {
	// Relation is the relation in the tuple set
	// +kubebuilder:validation:Required
	Relation string `json:"relation"`
}

// ComputedUserset defines a computed userset
type ComputedUserset struct {
	// Object defines the object in the computed userset
	Object string `json:"object,omitempty"`

	// Relation defines the relation in the computed userset
	// +kubebuilder:validation:Required
	Relation string `json:"relation"`
}

// AuthorizationModelStatus defines the observed state of AuthorizationModel
type AuthorizationModelStatus struct {
	// Conditions represent the latest available observations of the authorization model's current state
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// Phase represents the current phase of the authorization model
	// +kubebuilder:validation:Enum=Pending;Ready;Failed;Unknown
	Phase string `json:"phase,omitempty"`

	// ModelID is the ID of the authorization model in OpenFGA
	ModelID string `json:"modelID,omitempty"`

	// StoreID is the ID of the store where the model is deployed
	StoreID string `json:"storeID,omitempty"`

	// ObservedGeneration reflects the generation of the most recently observed AuthorizationModel
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// LastReconcileTime is the last time the resource was reconciled
	LastReconcileTime *metav1.Time `json:"lastReconcileTime,omitempty"`

	// ValidationErrors contains any validation errors from OpenFGA
	ValidationErrors []string `json:"validationErrors,omitempty"`

	// AppliedAt is the timestamp when the model was successfully applied
	AppliedAt *metav1.Time `json:"appliedAt,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Model ID",type="string",JSONPath=".status.modelID"
// +kubebuilder:printcolumn:name="Store ID",type="string",JSONPath=".status.storeID"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
// +kubebuilder:printcolumn:name="Applied At",type="date",JSONPath=".status.appliedAt"

// AuthorizationModel is the Schema for the authorizationmodels API
type AuthorizationModel struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AuthorizationModelSpec   `json:"spec,omitempty"`
	Status AuthorizationModelStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// AuthorizationModelList contains a list of AuthorizationModel
type AuthorizationModelList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AuthorizationModel `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AuthorizationModel{}, &AuthorizationModelList{})
}
