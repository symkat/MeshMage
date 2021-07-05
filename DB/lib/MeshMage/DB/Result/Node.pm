use utf8;
package MeshMage::DB::Result::Node;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MeshMage::DB::Result::Node

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Serializer");

=head1 TABLE: C<node>

=cut

__PACKAGE__->table("node");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'node_id_seq'

=head2 network_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 hostname

  data_type: 'text'
  is_nullable: 0

=head2 public_ip

  data_type: 'inet'
  is_nullable: 1

=head2 nebula_ip

  data_type: 'inet'
  is_nullable: 0

=head2 is_lighthouse

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 updated_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "node_id_seq",
  },
  "network_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "hostname",
  { data_type => "text", is_nullable => 0 },
  "public_ip",
  { data_type => "inet", is_nullable => 1 },
  "nebula_ip",
  { data_type => "inet", is_nullable => 0 },
  "is_lighthouse",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "updated_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 network

Type: belongs_to

Related object: L<MeshMage::DB::Result::Network>

=cut

__PACKAGE__->belongs_to(
  "network",
  "MeshMage::DB::Result::Network",
  { id => "network_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 node_attributes

Type: has_many

Related object: L<MeshMage::DB::Result::NodeAttribute>

=cut

__PACKAGE__->has_many(
  "node_attributes",
  "MeshMage::DB::Result::NodeAttribute",
  { "foreign.node_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-06-05 19:01:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uAjzCmzboMJp3bWDLcA1dQ

sub lighthouses {
    my ( $self ) = @_;

    return [ $self->network->search_related( 'nodes', { is_lighthouse => 1 } )->all ];
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
