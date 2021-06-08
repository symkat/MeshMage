use utf8;
package MeshMage::DB::Result::Network;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MeshMage::DB::Result::Network

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

=head1 TABLE: C<network>

=cut

__PACKAGE__->table("network");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'network_id_seq'

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 address

  data_type: 'inet'
  is_nullable: 0

=head2 tld

  data_type: 'text'
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
    sequence          => "network_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "address",
  { data_type => "inet", is_nullable => 0 },
  "tld",
  { data_type => "text", is_nullable => 0 },
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

=head2 machines

Type: has_many

Related object: L<MeshMage::DB::Result::Machine>

=cut

__PACKAGE__->has_many(
  "machines",
  "MeshMage::DB::Result::Machine",
  { "foreign.network_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 nodes

Type: has_many

Related object: L<MeshMage::DB::Result::Node>

=cut

__PACKAGE__->has_many(
  "nodes",
  "MeshMage::DB::Result::Node",
  { "foreign.network_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-06-05 18:43:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6IIpmu6yIntxXoIKJPNDQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
