# Contact/conversation search for users who may not search by phone number:
# name, email, contact id and CRM lead id only. Queries holding a long digit run
# never match names either, since WhatsApp contacts are often named after their number.
module Shawky::Patches::ContactSearch
  DIGIT_RUN = /\d{5,}/

  module_function

  def contacts(relation, query)
    term = "%#{query}%"
    scope = relation.where("contacts.custom_attributes->>'lead_id' ILIKE :term", term: term)
    scope = scope.or(relation.where(id: query)) if query.match?(/\A\d+\z/)
    return scope if query.match?(DIGIT_RUN)

    scope.or(relation.where('contacts.name ILIKE :term OR contacts.email ILIKE :term', term: term))
  end
end
